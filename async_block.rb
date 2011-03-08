# By Thomas Haggett (thomas@haggett.org)
# Who would be keen to know what this gets used for, if anything...
# ... and any patches :)

require 'eventmachine'

module EventMachine
  # This is an "escape" call - which will cause the thread of execution to jump
  # out to the run_deferred_callbacks loop. (grab a continuation before you go!)
  def self.break
    @@break.call 
  end
  
  # Monkeypatch Eventmachine internals to handle evented / procedural switch
  def self.run_deferred_callbacks # :nodoc:
    until (@resultqueue ||= []).empty?
      result,cback = @resultqueue.pop
      cback.call result if cback
    end

    # grab the current stack position so we can escape async jobs
    callcc { |cont| @@break = cont } unless defined?(@@break)
    
    # pop and execute jobs
    while job = @next_tick_mutex.synchronize { @next_tick_queue.shift }
      job.call 
    end
  end
  
  # Monkeypatch Deferrable to return the deferrable out of callback and errback to allow
  # chaining, i.e.:
  # DefaultDeferrable.new.callback { |thing| }.errback { |exception| }
  module Deferrable
    alias :callback_inner :callback
    alias :errback_inner :errback
    def callback(&block); callback_inner(&block); self; end
    def errback(&block); errback_inner(&block); self; end
  end
end

class Object
  # Immediately calls the block with a single object (out) and "halts" the
  # procedural stack. Evented code should be executed inside the block
  # and the out.return called when you're done to return a value or 
  # out.raise called if you want to throw an exception.
  def evented(&block)
    AsyncBlock.new.evented(&block)
  end
  
  # Cause the block to be executed on the next event machine cycle.
  # Returns a deferrable which succeeds with the return value or 
  # fails with an exception
  def procedural(name="", &block)
    SyncBlock.new( name, &block )
  end
end

class SyncBlock
  include EM::Deferrable
  def initialize( name, &block )
    @name, @caller = name, caller[2]
    spawn( &block )  
    errback { |exception| handle_exception(exception) unless @errbacks.size > 0 }
  end
  def spawn( &block )
    EM::next_tick {
      begin
        succeed(block.call)
      rescue
        fail($!)  
      end
    }
  end
  def handle_exception( exception )
    puts "Exception #{exception.inspect} raised during procedural block #{@name} spawned at #{@caller}"
    puts exception.backtrace.join("\n\t")
  end
end

class AsyncBlock

  # This executes a single spawn'd block and returns once it's done
  def self.single(then_exit=true, &inner)
    EM.error_handler { |e| raise e }
    EM.run { procedural(&inner).callback {
      EM::stop if then_exit
    }.errback { |exception|
      raise exception 
    }}
  end
    
  attr_accessor :continuation
  def evented( &block )
    handle(*callcc { |continuation|
      self.continuation = continuation
      block.call( self )
      EventMachine.break
    })
  end
  def return( value )
    EM::next_tick { self.continuation.call([:return, value]) }
  end
  def raise( exception )
    EM::next_tick { self.continuation.call([:raise, exception]) }
  end
  def handle( task, obj )
    Kernel.raise(obj) if task == :raise
    obj
  end
end

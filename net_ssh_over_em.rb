## Fuck around with SSH's event loop to actually run on top of eventmachine
## :)

class SelectInvocation
  def initialize( result )
    @result, @connections = result, []
  end
  
  def watch( io, reads, writes )
    @connections << EM.watch( io ) { |c|
      c.instance_variable_set( :@select, self )
      def c.notify_readable
        @select.clean_up([[@io], [], []])
      end
      def c.notify_writable
        @select.clean_up([[], [@io], []])
      end
      c.notify_readable = reads
      c.notify_writable = writes
    }
  end
  
  def timeout( timeout )
    
    if timeout == 0
      timeout = 0.1
    end
    @timer = EM.add_timer( timeout ) { self.clean_up( nil ) }
    
  end
  def clean_up(response)
    @timer && EM::cancel_timer(@timer)
    while c = @connections.shift
      c.detach
    end
    @result.return( response )
  end
end


class Net::SSH::Compat
  def self.io_select( read_array, write_array=nil, error_array=nil, timeout=nil )
    evented { |ret|
      write_array ||= []
      SelectInvocation.new( ret ).tap {|s|
        (read_array + write_array).uniq.each { |io|
          s.watch( io, read_array.include?(io), write_array.include?(io) )
        }
        raise "Implement error_array" if error_array
        s.timeout( timeout ) if timeout
      }
    }
  end
end
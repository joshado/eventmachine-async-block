# A contrived example.

require 'rubygems'
require 'eventmachine'
require 'thin'
require 'async_block'
require 'em-redis'

class CakeOrDeath
  def initialize
    @redis = EM::Protocols::Redis.connect
  end
  
  def redis_increment( key )

    evented { |ret|
    
      @redis.incr( key ) do |value|
        ret.return "Visits = #{value}"
      end

    }
    
  end

  def handle_request( env )
    case env["PATH_INFO"]
    when "/CAKE"

      [200, {}, "Yum #{redis_increment("visits")}"]

    when "/DEATH"
      
      raise "Die!"
      
    else

      [404, {}, "Not quite sure what you're looking for? #{env["PATH_INFO"]}"]

    end    
  end

  def call( env )  
    procedural("HTTP Request Handler") {
      
      handle_request( env )
      
    }.errback { |exception|
      
      env['async.callback'].call([500, {}, "Failed with exception: #{exception.inspect}"])
      
    }.callback { |response|
      
      env['async.callback'].call(response)
      
    }
        
    [-1, {}, []]
  end
end

EM::run {
  EM::next_tick {
    Thin::Server.start("0.0.0.0", 8080, CakeOrDeath.new)
  }
}
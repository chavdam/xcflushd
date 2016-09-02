require 'xcflushd'
require 'redis'
require '3scale_client'

module Xcflushd
  class Runner
    class << self

      def run(threescale_host, provider_key, redis_host, redis_port, auth_valid_min)
        redis = Redis.new(host: redis_host, port: redis_port, driver: :hiredis)
        storage = Storage.new(redis)
        threescale = ThreeScale::Client.new(provider_key: provider_key,
                                            host: threescale_host)
        reporter = Reporter.new(threescale)
        authorizer = Authorizer.new(threescale, redis, auth_valid_min)
        flusher = Flusher.new(reporter, authorizer, storage)

        flusher.flush
      end

    end
  end
end
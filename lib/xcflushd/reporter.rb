require '3scale_client'

module Xcflushd
  class Reporter

    class ReporterError < Flusher::XcflushdError
      def initialize(service_id, transaction, specific_msg)
        super("Error reporting this transaction: #{transaction} "\
              "for service with id #{service_id}. "\
              "#{specific_msg}")
      end
    end

    # Exception raised when the 3scale client is not called with the right
    # params. This happens when there are programming errors.
    class ThreeScaleBadParams < ReporterError
      def initialize(service_id, transaction)
        super(service_id, transaction,
              'There might be a bug in the program.'.freeze)
      end
    end

    # Exception raised when the 3scale client is called with the right params
    # but it returns a ServerError. Most of the time this means that 3scale is
    # unreachable, although it could also be caused by a bug in the 3scale
    # service management API.
    class ThreeScaleInternalError < ReporterError
      def initialize(service_id, transaction)
        super(service_id, transaction, '3scale seems to be unreachable.'.freeze)
      end
    end

    # Exception raised when the 3scale client made the call, but did not
    # succeed. This happens when the credentials are invalid. For example, when
    # an invalid provider key is used.
    class ThreeScaleAuthError < ReporterError
      def initialize(service_id, transaction)
        super(service_id, transaction,
              'Invalid credentials. Check the provider key'.freeze)
      end
    end

    def initialize(threescale_client)
      @threescale_client = threescale_client
    end

    def report(service_id, credentials, usage)
      transaction = credentials.creds.merge(usage: usage)

      begin
        resp = threescale_client.report(transactions: [transaction],
                                        service_id: service_id)
      # TODO: get rid of the coupling with ThreeScale::ServerError
      rescue ThreeScale::ServerError, SocketError
        # We'll get a SocketError if there's a timeout when contacting 3scale.
        raise ThreeScaleInternalError.new(service_id, transaction)
      rescue ArgumentError
        raise ThreeScaleBadParams.new(service_id, transaction)
      end

      raise ThreeScaleAuthError.new(service_id, transaction) unless resp.success?
      true
    end

    private

    attr_reader :threescale_client

  end
end

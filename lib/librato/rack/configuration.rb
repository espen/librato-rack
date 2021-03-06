

module Librato
  class Rack
    # Holds configuration for Librato::Rack middleware to use.
    # Acquires some settings by default from environment variables,
    # but this allows easy setting and overrides.
    #
    # @example
    #   config = Librato::Rack::Configuration.new
    #   config.user  = 'mimo@librato.com'
    #   config.token = 'mytoken'
    #
    class Configuration
      EVENT_MODES = [:eventmachine, :synchrony]

      DEFAULT_SUITES = [:rack, :rack_method, :rack_status]

      attr_accessor :user, :token, :autorun, :api_endpoint, :tracker,
                    :source_pids, :log_level, :log_prefix, :log_target,
                    :disable_rack_metrics, :flush_interval, :proxy, :suites
      attr_reader :prefix, :source, :deprecations

      def initialize
        # set up defaults
        self.tracker = nil
        self.api_endpoint = Librato::Metrics.api_endpoint
        self.flush_interval = 60
        self.source_pids = false
        self.log_prefix = '[librato-rack] '
        @listeners = []
        @deprecations = []

        load_configuration
      end

      def event_mode
        @event_mode
      end

      # set event_mode, valid options are EVENT_MODES or
      # nil (the default) if not running in an evented context
      def event_mode=(mode)
        mode = mode.to_sym if mode
        # reject unless acceptable mode, allow for turning event_mode off
        if [*EVENT_MODES, nil].include?(mode)
          @event_mode = mode
        else
          # TODO log warning
        end
      end

      def explicit_source?
        !!@explicit_source
      end

      # check environment variables and capture current state
      # for configuration
      def load_configuration
        self.user = ENV['LIBRATO_USER']
        self.token = ENV['LIBRATO_TOKEN']
        self.autorun = detect_autorun
        self.prefix = ENV['LIBRATO_PREFIX']
        self.source = ENV['LIBRATO_SOURCE']
        self.log_level = ENV['LIBRATO_LOG_LEVEL'] || :info
        self.proxy = ENV['LIBRATO_PROXY'] || ENV['https_proxy'] || ENV['http_proxy']
        self.event_mode = ENV['LIBRATO_EVENT_MODE']
        self.suites = ENV['LIBRATO_SUITES'] || ''
        check_deprecations
      end

      def prefix=(prefix)
        @prefix = prefix
        @listeners.each { |l| l.prefix = prefix }
      end

      def register_listener(listener)
        @listeners << listener
      end

      def source=(src)
        @source = src
        @explicit_source = !!@source
      end

      def dump
        fields = {}
        %w{user token log_level source prefix flush_interval source_pids suites}.each do |field|
          fields[field.to_sym] = self.send(field)
        end
        fields[:metric_suites] = metric_suites.fields
        fields
      end

      def metric_suites
        @metric_suites ||= case suites.downcase.strip
                           when 'all'
                             SuitesAll.new
                           when 'none'
                             SuitesNone.new
                           else
                             Suites.new(suites, default_suites)
                           end
      end

      private

      def default_suites
        DEFAULT_SUITES
      end

      def check_deprecations
        if self.disable_rack_metrics
          deprecate "disable_rack_metrics configuration option will be removed in a future release, please use config.suites = 'none' instead."
        end
      end

      def deprecate(message)
        @deprecations << message
      end

      def detect_autorun
        case ENV['LIBRATO_AUTORUN']
        when '0', 'FALSE'
          false
        when '1', 'TRUE'
          true
        else
          nil
        end
      end

    end
  end
end

require_relative 'configuration/suites'

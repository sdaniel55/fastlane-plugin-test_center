module TestCenter
  module Helper
    module MultiScanManager
      class RetryingScan
        def initialize(options = {})
          @options = options
          @retrying_scan_helper = RetryingScanHelper.new(@options)
        end

        # :nocov:
        def scan_config
          Scan.config
        end

        def scan_cache
          Scan.cache
        end
        # :nocov:

        def prepare_scan_config_for_destination
          # this allows multi_scan's `destination` option to be picked up by `scan`
          scan_config._values.delete(:device)
          scan_config._values.delete(:devices)
          scan_cache.clear
        end

        def update_scan_options
          valid_scan_keys = Fastlane::Actions::ScanAction.available_options.map(&:key)
          scan_options = @options.select { |k,v| valid_scan_keys.include?(k) }
                                  .merge(@retrying_scan_helper.scan_options)

          prepare_scan_config_for_destination
          scan_options.each do |k,v|
            scan_config.set(k,v) unless v.nil?
          end
        end

        # :nocov:
        def self.run(options)
          RetryingScan.new(options).run
        end
        # :nocov:

        def run
          try_count = @options[:try_count] || 1
          begin
            # TODO move delete_xcresults to `before_testrun`
            @retrying_scan_helper.before_testrun
            update_scan_options
            
            values = scan_config.values(ask: false)
            values[:xcode_path] = File.expand_path("../..", FastlaneCore::Helper.xcode_path)
            FastlaneCore::PrintTable.print_values(
              config: values,
              hide_keys: [:destination, :slack_url],
              title: "Summary for scan #{Fastlane::VERSION}"
            ) unless FastlaneCore::Helper.test?

            Scan::Runner.new.run
            @retrying_scan_helper.after_testrun
            true
          rescue FastlaneCore::Interface::FastlaneTestFailure => e
            FastlaneCore::UI.message("retrying_scan after test failure")
            @retrying_scan_helper.after_testrun(e)
            retry if @retrying_scan_helper.testrun_count < try_count
            false
          rescue FastlaneCore::Interface::FastlaneBuildFailure => e
            FastlaneCore::UI.message("retrying_scan after build failure")
            @retrying_scan_helper.after_testrun(e)
            retry if @retrying_scan_helper.testrun_count < try_count
            false
          end
        end
      end
    end
  end
end

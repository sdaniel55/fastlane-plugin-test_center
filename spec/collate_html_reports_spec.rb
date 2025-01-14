def testidentifiers_from_xmlreport(report)
  testable = REXML::XPath.first(report, "//section[@id='test-suites']")
  testsuites = REXML::XPath.match(testable, "section[contains(@class, 'test-suite')]")
  testidentifiers = []
  testsuites.each do |testsuite|
    testidentifiers += REXML::XPath.match(testsuite, ".//*[contains(@class, 'tests')]//*[contains(@class, 'test')]//*[contains(@class, 'title')]").map do |testcase|
      "#{testsuite.attribute('id').value}/#{testcase.text.strip}"
    end
  end
  testidentifiers
end

module Fastlane::Actions

  html_report_1 = File.open('./spec/fixtures/report.html')
  html_report_2 = File.open('./spec/fixtures/report-2.html')

  atomicboy_ui_testsuite_file = File.read('./spec/fixtures/atomicboy_uitestsuite.html')
  atomicboy_ui_testsuite_file2 = File.read('./spec/fixtures/atomicboy_uitestsuite-2.html')
  atomicboy_ui_testsuite_file3 = File.read('./spec/fixtures/atomicboy_uitestsuite-3.html')
  atomicboy_ui_testsuite_file4 = File.read('./spec/fixtures/atomicboy_uitestsuite-4.html')

  describe "CollateHtmlReportsAction" do
    before(:each) do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:open).and_call_original
      @atomicboy_ui_testsuite = REXML::Document.new(atomicboy_ui_testsuite_file).root
      @atomicboy_ui_testsuite2 = REXML::Document.new(atomicboy_ui_testsuite_file2).root
      @atomicboy_ui_testsuite3 = REXML::Document.new(atomicboy_ui_testsuite_file3).root
      @atomicboy_ui_testsuite4 = REXML::Document.new(atomicboy_ui_testsuite_file4).root
    end

    describe 'it handles invalid data' do
      it 'a failure occurs when non-existent HTML file is specified' do
        fastfile = "lane :test do
          collate_html_reports(
            reports: ['path/to/non_existent_html_report.html'],
            collated_report: 'path/to/report.html'
          )
        end"
        expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
          raise_error(FastlaneCore::Interface::FastlaneError) do |error|
            expect(error.message).to match("Error: HTML report not found: 'path/to/non_existent_html_report.html'")
          end
        )
      end
    end

    describe 'it handles valid data' do
      it 'simply copies a :reports value containing one report' do
        fastfile = "lane :test do
          collate_html_reports(
            reports: ['path/to/fake_html_report.html'],
            collated_report: 'path/to/report.html'
          )
        end"
        allow(File).to receive(:exist?).with('path/to/fake_html_report.html').and_return(true)
        allow(File).to receive(:open).with('path/to/fake_html_report.html').and_yield(File.open('./spec/fixtures/report.html'))
        expect(FileUtils).to receive(:cp).with('path/to/fake_html_report.html', 'path/to/report.html')
        Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      end
    end

    describe 'it handles malformed data' do
      it 'fixes and merges malformed html files' do
        malformed_report = File.open('./spec/fixtures/malformed-report.html')
        allow(File).to receive(:exist?).with('path/to/fake_html_report_1.html').and_return(true)
        allow(File).to receive(:new).with('path/to/fake_html_report_1.html').and_return(html_report_1)
        allow(File).to receive(:exist?).with('path/to/malformed-report.html').and_return(true)

        second_reports = [
          malformed_report,
          html_report_1
        ]
        allow(File).to receive(:new).with('path/to/malformed-report.html') do
          second_reports.shift
        end

        allow(Fastlane::Actions::CollateHtmlReportsAction).to receive(:repair_malformed_html).with('path/to/malformed-report.html')
        Fastlane::Actions::CollateHtmlReportsAction.opened_reports(
          [
            'path/to/fake_html_report_1.html',
            'path/to/malformed-report.html'
          ]
        )
      end

      it 'finds and fixes unescaped less-than or greater-than characters' do
        malformed_report = File.open('./spec/fixtures/malformed-report.html')
        allow(File).to receive(:read).with('path/to/malformed-report.html').and_return(malformed_report.read)
        patched_file = StringIO.new
        allow(File).to receive(:open).with('path/to/malformed-report.html', 'w').and_yield(patched_file)
        Fastlane::Actions::CollateHtmlReportsAction.repair_malformed_html('path/to/malformed-report.html')
        expect(patched_file.string).to include('&lt;unknown&gt;')
      end
    end
  end
end

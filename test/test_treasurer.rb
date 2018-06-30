require 'helper'
require 'ruby-prof'
#require 'ruby-prof/test'

class TestTreaurer < MiniTest::Test
	#include RubyProf::Test
	#PROFILE_OPTIONS[:
	def testfolder
		'test/myaccount'
	end
	def test_setup
		FileUtils.rm_r(testfolder) if FileTest.exist? testfolder
		Treasurer.init_root_folder('test/myaccount', {})
		Dir.chdir('test/myaccount') do
      FileUtils.cp('../external_accounts.rb', '.')
      FileUtils.cp('../account_choices.rb', '.')
			Treasurer.add_file('../bankaccountstatement.csv', 'FirstBank', {})
			Treasurer.status
			Treasurer.add_file('../otheraccountstatement.csv', 'SecondBank', {})
			Treasurer.add_folder_of_files('../multiple')
			Treasurer.status h: :component
			RubyProf.start
			Treasurer.create_report t: Date.parse('2010-09-07'), b: 40, a: 35
			result = RubyProf.stop
			result.eliminate_methods!([/Array#map/, /Array#each/])
			printer = RubyProf::GraphHtmlPrinter.new(result)
			File.open('timing.html', 'w'){|f| printer.print(f, {})}
			reporter = Treasurer.fetch_reporter(t: Date.parse('2010-09-07'), b: 40, a: 35)
			reporter.generate_accounts
      assert_equal(1032.08, reporter.equities.values[0].balance.round(2))
      assert_equal(1825.28, reporter.equities.values[0].projected_balance(Date.parse('2010-10-09')).round(2))
		end
		#FileUtils.rm_r(testfolder) if FileTest.exist? testfolder
	end
end

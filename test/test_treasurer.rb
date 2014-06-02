require 'helper'

class TestTreasurer < Test::Unit::TestCase
	def testfolder
		'test/myaccount'
	end
	def test_setup
		FileUtils.rm_r(testfolder) if FileTest.exist? testfolder
		Treasurer.init_root_folder('test/myaccount', {})
		Dir.chdir('test/myaccount') do
			Treasurer.add_file('../bankaccountstatement.csv', 'FirstBank', {})
			Treasurer.status
			Treasurer.add_file('../otheraccountstatement.csv', 'SecondBank', {})
			Treasurer.add_folder_of_files('../multiple')
			Treasurer.status h: :component
			Treasurer.create_report t: Date.parse('2010-09-07'), b: 40, a: 35
		end
		#FileUtils.rm_r(testfolder) if FileTest.exist? testfolder
	end
end

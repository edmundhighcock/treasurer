require 'helper'

class TestTreasurer < Test::Unit::TestCase
	def testfolder
		'test/myaccount'
	end
	def test_setup
		FileUtils.rm_r(testfolder) if FileTest.exist? testfolder
		Treasurer.init_root_folder('test/myaccount', {})
		Dir.chdir('test/myaccount') do
			Treasurer.add_file('../equityaccount.cvs', 'FirstBank', {})
			Treasurer.status
			Treasurer.add_file('../incomeaccount.cvs', 'SecondBank', {})
			Treasurer.status h: :component
			Treasurer.report t: Date.parse('2010-09-07'), b: 40, a: 20
		end
	end
end

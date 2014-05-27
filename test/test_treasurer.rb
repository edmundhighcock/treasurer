require 'helper'

class TestTreasurer < Test::Unit::TestCase
	def testfolder
		'test/myaccount'
	end
	def test_setup
		FileUtils.rm_r(testfolder) if FileTest.exist? testfolder
		Treasurer.init_root_folder('test/myaccount', {})
		Dir.chdir('test/myaccount') do
			Treasurer.add_file('../equityaccount.cvs', 'Lloyds', {})
			Treasurer.status
			Treasurer.status h: :component
			Treasurer.report t: Date.parse('2010-09-03'), b: 20, a: 10
		end
	end
end

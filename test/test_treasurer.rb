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
		end
	end
end

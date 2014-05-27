require 'helper'

class TestTreasurer < Test::Unit::TestCase
	def test_setup
		Treasurer.init('test/myaccount', {})

	end
end

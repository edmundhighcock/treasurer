#class CodeRunner::Budget
module Treasurer::LocalCustomisations


REGULAR_TRANSFERS = {
	[:FirstBank, :SecondBank] =>{
		topup: {size: 200, period: [1, :month], monthday: 1, end: Date.parse("01/10/2014")},
  },
  [:FirstBank, :Rent] =>{
		house: {size: 600, period: [1, :month], monthday: 20, end: Date.parse("01/07/2013")},
  },
  [:Income, :FirstBank] =>{
		pay: {size: 1200, period: [1, :month], monthday: 1, end: Date.parse("01/07/2014")},
  },
 
}

REGULAR_TRANSFERS.default = {}

FUTURE_TRANSFERS = {
	[:Income, :SecondBank] =>{
		bonus: {size: 100, date: Date.parse("26/09/2010")},
  },
  [:FirstBank, :PersonalLoans] =>{
		payfriend: {size: 640, date: Date.parse("25/09/2010")},
		borrowfromfriend: {size: -840, date: Date.parse("28/09/2010")},
  },
 
}

FUTURE_TRANSFERS.default = {}



ACCOUNT_INFO = {
	Monthly: {linked_account: :FirstBank, period: [1, :month], monthday: 1, start: nil, end: nil, discretionary: false},
	MonthlySecondBank: {linked_account: :SecondBank, period: [1, :month], monthday: 1, start: nil, end: nil, discretionary: false},
	Weekly: {linked_account: :FirstBank, period: [7, :day], monthday: nil, start: nil, end: nil, discretionary: true},
	WeeklySecondBank: {linked_account: :SecondBank, period: [7, :day], monthday: nil, start: nil, end: nil, discretionary: true},
	MyHoliday: {linked_account: :SecondBank, period: [1, :day], monthday: nil, start: Date.parse("02/12/2013"), end: Date.parse("2/01/2014"), discretionary: false},
	PersonalLoans: {type: :Liability},
	FirstBank: {type: :Asset},
	SecondBank: {type: :Asset},
	Pay: {linked_account: :FirstBank, type: :Income},
}

def in_date(item)
	(!item[:start] or date >= item[:start]) and (!item[:end] || date <= item[:end])
end

def account_type(account)
	case account
	when :Food, :Phone, :Rent, :Cash, :Entertainment, :Books, :Insurance
		:Expense
	when :FirstBank, :SecondBank
		:Asset
	when :PersonalLoans
		:Liability
	else
		:Expense
	end
end

def red_line(account, date)
	case account
	when :FirstBank
		-350
	when :SecondBank
		0
	else
		0
	end
end


def sub_account
	case description
	when /co-op|sainsbury/i 
		:Food
	when /insurance/i
		:Insurance
	when /Vodafone/i
		:Phone
	when /Adams/i
		:Rent
	when /Carfax|Lnk/i
		:Cash
	when /andalus/i, /angels/i, /maggie arms/i, /barley mow/i
		:Entertainment
	when /blackwell/i
		:Books
	else
		:Unknown
	end
end

def external_account
	case description
	when /Vodafone/i
		:Monthly
	when /norries/i
		:PersonalLoans
	when /my employer/i
		:Pay
	else
		case sub_account
		when :Food, :Entertainment
			:Weekly
		when :Insurance, :Phone, :Rent
			:Monthly
		when :Books, :Cash
			:WeeklySecondBank
		else
			:Unknown
		end
	end
end
	
end

#class CodeRunner::Budget
module Treasurer::LocalCustomisations

	@excluding = []
FUTURE_EXPENDITURE = {
	:FirstBank => {
		skitrip: { size: 300, date: Date.parse("04/10/2010") },
		webhosting: { size: 150, date: Date.parse("01/11/2010") },
		cartax: [
			{size: 120, date: Date.parse("01/01/2014")},
		],

		counciltax: [
			{size: 108, date: Date.parse("12/12/2010")},
			{size: 108, date: Date.parse("05/01/2011")},
			{size: 108, date: Date.parse("05/02/2011")},
		],
		heating: [
			{size: 250, date: Date.parse("12/12/2013")},
			{size: 250, date: Date.parse("05/2/2014")},
		],

},
  :SecondBank => {
		doctor: {size: 400, date: Date.parse("01/03/2014") },
		windows: {size: 600, date: Date.parse("01/12/2013") },
}
}

FUTURE_EXPENDITURE.default = {}

REGULAR_INCOME = {
	:FirstBank => {
		pay: {size: 3750, period: [1, :month], monthday: 28, end: Date.parse("01/10/2014")},
},
	:SecondBank => {
		contractwork: {size: 750, period: [1, :month], monthday: 28, end: Date.parse("01/10/2014")},
},
}

REGULAR_INCOME.default = {}

REGULAR_EXPENDITURE = {
	:FirstBank => {
		house: {size: 600, period: [1, :month], monthday: 20, end: Date.parse("01/07/2011")},
}
}
REGULAR_EXPENDITURE.default = {}

REGULAR_TRANSFERS = {
	[:FirstBank, :SecondBank] =>{
		topup: {size: 600, period: [1, :month], monthday: 1, end: Date.parse("01/10/2014")},
}
}

REGULAR_TRANSFERS.default = {}


# One off expected gains
FUTURE_INCOME = {
	:FirstBank => {
		stipend: [
			{ size: 1200*3, date: Date.parse("25/05/2011") },
			{ size: 1200*3, date: Date.parse("25/02/2011") },
			{ size: 4300, date: Date.parse("20/09/2010") },
			{ size: 4300, date: Date.parse("20/12/2010") }
		],
		expenses: [
			{ size: 1085+41, date: Date.parse("1/12/2013") }
		],

},
  :SecondBank => {

}
}

FUTURE_INCOME.default = {}


BUDGETS = {
	Monthly: {account: :FirstBank, period: [1, :month], monthday: 1, start: nil, end: nil, discretionary: false},
	MonthlySecondBank: {account: :SecondBank, period: [1, :month], monthday: 1, start: nil, end: nil, discretionary: false},
	Weekly: {account: :FirstBank, period: [7, :day], monthday: nil, start: nil, end: nil, discretionary: true},
	WeeklySecondBank: {account: :SecondBank, period: [7, :day], monthday: nil, start: nil, end: nil, discretionary: true},
	MyHoliday: {account: :SecondBank, period: [1, :day], monthday: nil, start: Date.parse("02/12/2013"), end: Date.parse("2/01/2014"), discretionary: false},
}

# Transfer budgets
TRANSFERS = {
	FirstBankSecondBank: {account: :SecondBank, period: [1, :day], monthday: nil, start: Date.parse("27/06/2013"), end: nil, discretionary: false},
	#FriendtoSecondBank: {account: :SecondBank, period: [1, :day], monthday: nil, start: Date.parse("27/06/2013"), end: nil, discretionary: false},
}

def in_date(item)
	(!item[:start] or date >= item[:start]) and (!item[:end] || date <= item[:end])
end

def account_type(account)
	case account
	when :Food, :Phone, :Rent, :Cash, :Entertainment, :Books
		:Expense
	when :FirstBank, :SecondBank
		:Asset
	when :PersonalLoans
		:Liability
	end
end


def external_account
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
	when /norries/i
		:PersonalLoans
	else
		:Unknown
	end
end

def budget
	case description
	when /Vodafone/i
		:Monthly
	else
		case external_account
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

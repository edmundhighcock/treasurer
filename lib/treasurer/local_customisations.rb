class CodeRunner::Budget

	@excluding = []
FUTURE_EXPENDITURE = {
	#"Lloyds" => {
		#skitrip: { size: 300, date: Date.parse("04/10/2010") },
		#dreamhost: { size: 150, date: Date.parse("01/11/2010") },
		#cartax: [
			#{size: 120, date: Date.parse("01/01/2014")},
		#],

		#counciltax: [
			#{size: 108, date: Date.parse("12/12/2013")},
			#{size: 108, date: Date.parse("05/01/2014")},
			#{size: 108, date: Date.parse("05/02/2014")},
		#],
		#heating: [
			#{size: 250, date: Date.parse("12/12/2013")},
			#{size: 250, date: Date.parse("05/2/2014")},
		#],

#},
  #"Barclays" => {
		#doctor: {size: 400, date: Date.parse("01/03/2014") },
		#windows: {size: 600, date: Date.parse("01/12/2013") },
#}
}

FUTURE_EXPENDITURE.default = {}

REGULAR_INCOME = {
	#"Lloyds" => {
		#pay: {size: 3750, period: [1, :month], monthday: 28, end: Date.parse("01/10/2014")},
#},
	#"Barclays" => {
		#contractwork: {size: 750, period: [1, :month], monthday: 28, end: Date.parse("01/10/2014")},
#},
}

REGULAR_INCOME.default = {}

REGULAR_EXPENDITURE = {
	"Lloyds" => {
		house: {size: 600, period: [1, :month], monthday: 20, end: Date.parse("01/07/2011")},
}
}
REGULAR_EXPENDITURE.default = {}

REGULAR_TRANSFERS = {
	["Lloyds", "Barclays"] =>{
		topup: {size: 600, period: [1, :month], monthday: 1, end: Date.parse("01/10/2014")},
}
}

REGULAR_TRANSFERS.default = {}


# One off expected gains
FUTURE_INCOME = {
	"Lloyds" => {
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
  "Barclays" => {

}
}

FUTURE_INCOME.default = {}


BUDGETS = {
	Monthly: {account: "Lloyds", period: [1, :month], monthday: 1, start: nil, end: nil, discretionary: false},
	MonthlyBarclays: {account: "Barclays", period: [1, :month], monthday: 1, start: nil, end: nil, discretionary: false},
	#Weekly: {period: [7, :days], monthday: nil, start: nil, end: nil, discretionary: false},
	WeeklyBarclays: {account: "Barclays", period: [7, :day], monthday: nil, start: nil, end: nil, discretionary: true},
	MyHoliday: {account: "Barclays", period: [1, :day], monthday: nil, start: Date.parse("02/12/2013"), end: Date.parse("2/01/2014"), discretionary: false},
}

# Transfer budgets
TRANSFERS = {
	LloydsBarclays: {account: "Barclays", period: [1, :day], monthday: nil, start: Date.parse("27/06/2013"), end: nil, discretionary: false},
	#AmberBarclays: {account: "Barclays", period: [1, :day], monthday: nil, start: Date.parse("27/06/2013"), end: nil, discretionary: false},
}

def in_date(item)
	(!item[:start] or date >= item[:start]) and (!item[:end] || date <= item[:end])
end


def category
	return :Unknown
end

def budget
	case description
	when /Vodafone/i
		:Monthly
	when /Carfax/i
		:WeeklyBarclays
	end
end
	
end

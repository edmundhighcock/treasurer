
class Treasurer
class Reporter
	#include LocalCustomisations
	def initialize(runner, options)
		@runner = runner
		@days_ahead = options[:days_ahead]||180
		@days_before = options[:days_before]||360
		@today = options[:today]||Date.today
		@start_date = @today - @days_before
		@runs = runner.component_run_list.values
		@indateruns = runs.find_all{|r| r.days_ago < numdays}
	  @accounts = runs.map{|r| r.account}.uniq
	end
	# Within the range of the report, return a list
	# of the dates of the beginning of each budget
	# period, along with a list of the expenditures
	# for each period and a list of the items within
	# each period
	def budget_expenditure(budget, budget_info, options={})
		dates = []
		expenditures = []
		budget_items = []
		date = budget_info[:end]||@today
		start_date = [(budget_info[:start]||@start_date), @start_date].max
		expenditure = 0
		items_temp = []
		items = @runner.component_run_list.values.find_all{|r| r.budget == budget and r.in_date(budget_info)}
		#ep ['items', items]
		#ep ['budget', budget]
		counter = 0
		if not budget_info[:period]
			dates.push date
			budget_items.push items
			expenditures.push (items.map{|r| r.debit - r.credit}+[0]).sum
		else

			case budget_info[:period][1]
			when :month
				while date > @start_date
					items_temp += items.find_all{|r| r.date == date}
					if date.mday == (budget_info[:monthday] or 1)
						counter +=1
						if counter % budget_info[:period][0] == 0
							expenditure = (items_temp.map{|r| r.debit - r.credit}+[0]).sum
							dates.push date
							expenditures.push expenditure
							budget_items.push items_temp
							items_temp = []
							expenditure = 0
						end
					end
					date-=1
				end
			when :day
				while date > @start_date
					items_temp += items.find_all{|r| r.date == date}
					#expenditure += (budget_items[-1].map{|r| r.debit}+[0]).sum
					counter +=1
					if counter % budget_info[:period][0] == 0
						expenditure = (items_temp.map{|r| r.debit - r.credit}+[0]).sum
						dates.push date
						expenditures.push expenditure
						budget_items.push items_temp
						items_temp = []
						expenditure = 0
					end
					date-=1
				end
			end
		end

		[dates, expenditures, budget_items]

	end
	# Get a list of budgets to be included in the report
	# i.e. budgets with non-empty expenditure
	def get_actual_budgets
		@actual_budgets = BUDGETS.dup
		BUDGETS.keys.each do |budget|
			@actual_budgets.delete(budget) if budget_expenditure(budget, BUDGETS[budget])[0].size == 0
		end
	end
	# Find all discretionary budgets and estimate the future
	# expenditure from that budget based on past
	# expenditure (currently only a simple average)
	def get_projected_budgets
		 @projected_budgets = Hash[actual_budgets.dup.find_all{|k,v| v[:discretionary]}]
		 @projected_budgets = budgets_with_averages(runner,projected_budgets, today - numdays, today: today)
	end
	def report
		get_actual_budgets
		get_projected_budgets
	end
end
end

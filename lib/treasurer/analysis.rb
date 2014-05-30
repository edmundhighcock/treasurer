
class Treasurer::Reporter
module Analysis
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
	# Work out the average spend from the budget and include it in the budget info
	def budgets_with_averages(budgets, options={})
	 projected_budgets = budgets.dup
	 projected_budgets.each{|key,v| projected_budgets[key]=projected_budgets[key].dup}
	 projected_budgets.each do |budget, budget_info|
		 #budget_info = budgets[budget]
		 dates, expenditures, items = budget_expenditure(budget, budget_info)
		 budget_info[:average] = expenditures.mean rescue 0.0
	 end
	 projected_budgets
	end
	# Work out the projected spend from the budget and include it in the budget info
	def budgets_with_projections(budgets, options={})
	 projected_budgets = budgets.dup
	 projected_budgets.each{|key,v| projected_budgets[key]=projected_budgets[key].dup}
	 projected_budgets.each do |budget, budget_info|
		 #budget_info = budgets[budget]
		 dates, expenditures, items = budget_expenditure(budget, budget_info)
		 budget_info[:projection] = expenditures.mean rescue 0.0
	 end
	 projected_budgets
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
		 @projected_budgets = Hash[@actual_budgets.dup.find_all{|k,v| v[:discretionary]}]
		 @projected_budgets = budgets_with_projections(@projected_budgets)
	end
	# Calculate the sum of all items within future
	# items that fall before end_date
	def sum_future(future_items, end_date, options={})
	  #end_date = @today + @days_ahead
		sum = future_items.inject(0.0) do |sum, (name, item)| 
			item = [item] unless item.kind_of? Array
			value = item.inject(0.0) do |value,info|
				value += info[:size] unless ((@today||Date.today) > info[:date]) or (info[:date] > end_date) # add unless we have already passed that date
				value
				
			end
			#ep ['name2223', name, item, value, end_date, @today, (@today||Date.today > item[0][:date]), (item[0][:date] > end_date)]
			sum + value
			#rcp.excluding.include?(name) ? sum : sum + value
		end
		sum
	end
	# Sum every future occurence of the given 
	# regular items that falls within the budget period
	def sum_regular(regular_items, end_date, options={})
	  #end_date = @today + @days_ahead
		sum = regular_items.inject(0) do |sum, (name, item)|	
			item = [item] unless item.kind_of? Array
#			  ep item
			value = item.inject(0) do |value,info|
				finish = (info[:end] and info[:end] < end_date) ? info[:end] : end_date
				#today = (Time.now.to_i / (24.0*3600.0)).round
				 
				nunits = 0
				counter = info[:period][0] == 1 ? 0 : nil
				unless counter
					date = @today
					counter = 0
					case info[:period][1]
					when :month
						while date >= (info[:start] or Date.today)
							counter +=1 if date.mday == (info[:monthday] or 1)
							date -= 1
						end
					when :year
						while date >= (info[:start] or Date.today) 
							counter +=1 if date.yday == (info[:yearday] or 1)
							date -= 1
						end
					when :day
						while date > (info[:start] or Date.today)
							counter +=1
							date -= 1
						end
					end
				end
				date = @today
				case info[:period][1]
				when :month
					#p date, info
					while date <= finish 
						if date.mday == (info[:monthday] or 1)
							nunits += 1 if counter % info[:period][0] == 0
							counter +=1 
						end
						date += 1
					end
				when :year
					while date <= finish
						if date.yday == (info[:yearday] or 1)
							nunits += 1 if counter % info[:period][0] == 0
							counter +=1
						end
						date += 1
					end
				when :day
					while date <= finish
						nunits += 1 if counter % info[:period][0] == 0
						counter +=1
						date += 1
					end
				end



        #ep ['name2234', name, info, @projected_budget_factor] if info[:discretionary]

				value + nunits * (info[:size]||info[:projection]*(@projected_budget_factor||1.0))

			end
			sum + value
			#(rcp.excluding? and rcp.excluding.include?(name)) ? sum : sum + value
		end
		sum
	end
end
	include Analysis
end

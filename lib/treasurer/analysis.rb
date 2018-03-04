
class Treasurer::Reporter
module Analysis
	# Within the range of the report, return a list
	# of the dates of the beginning of each account
	# period, along with a list of the expenditures
	# for each period and a list of the items within
	# each period
	def account_expenditure(account, options={})
		dates = []
		expenditures = []
		account_items = []
		date = account.info[:end]||@today
		#start_date = [(account.info[:start]||@start_date), @start_date].max
		expenditure = 0
		items_temp = []
    items = @runner.component_run_list.values.find_all{|r| r.external_account == account.name and r.in_date(account.info) and @accounts_hash[r.account].currency == account.currency}
    #ep ['items', items.map{|i| i.date}]
    #ep ['account', account.name_c]
		counter = 0
		if not account.info[:period]
			dates.push date
			account_items.push items
			expenditures.push (items.map{|r| (r.deposit - r.withdrawal) * (account.info[:external] ? -1 : 1)}+[0]).sum
		else

			case account.info[:period][1]
			when :month
				while date > @start_date
					items_temp += items.find_all{|r| r.date == date}
					if date.mday == (account.info[:monthday] or 1)
						counter +=1
						if counter % account.info[:period][0] == 0
							expenditure = (items_temp.map{|r| (r.deposit - r.withdrawal) * (account.info[:external] ? -1 : 1)}+[0]).sum
							dates.push date
							expenditures.push expenditure
							account_items.push items_temp
							items_temp = []
							expenditure = 0
						end
					end
					date-=1
				end
			when :day
				while date > @start_date
					items_temp += items.find_all{|r| r.date == date}
					#expenditure += (account_items[-1].map{|r| r.debit}+[0]).sum
					counter +=1
					if counter % account.info[:period][0] == 0
						expenditure = (items_temp.map{|r| (r.deposit - r.withdrawal) * (account.info[:external] ? -1 : 1)}+[0]).sum
						dates.push date
						expenditures.push expenditure
						account_items.push items_temp
						items_temp = []
						expenditure = 0
					end
					date-=1
				end
			end
		end

		[dates, expenditures, account_items]

	end
	# Work out the average spend from the account and include it in the account info
	def accounts_with_averages(accounts, options={})
	 projected_accounts_info = accounts.dup
	 projected_accounts_info.each{|key,v| projected_accounts_info[key]=projected_accounts_info[key].dup}
	 projected_accounts_info.each do |account, account_info|
		 #account_info = accounts[account]
		 _dates, expenditures, _items = account_expenditure(account, account_info)
     account.average = expenditures.mean rescue 0.0
	 end
	 projected_accounts_info
	end
	# Work out the projected spend from the account and include it in the account info
	def accounts_with_projections(projected_accounts, options={})
	 #projected_accounts_info = accounts.dup
	 #projected_accounts_info.each{|key,v| projected_accounts_info[key]=projected_accounts_info[key].dup}
	 projected_accounts.each do |account|
		 #account_info = accounts[account]
		 _dates, expenditures, _items = account_expenditure(account)
		 account.projection = expenditures.mean rescue 0.0
	 end
   projected_accounts.map{|acc| [acc, acc.info]}.to_h
	end
	## Get a list of accounts to be included in the report
	## i.e. accounts with non-empty expenditure
	#def get_actual_accounts
		#@actual_accounts = ACCOUNT_INFO.dup
		#ACCOUNT_INFO.keys.each do |account|
			#@actual_accounts.delete(account) if account_expenditure(account, ACCOUNT_INFO[account])[0].size == 0
		#end
	#end
	# Find all discretionary accounts and estimate the future
	# expenditure from that account based on past
	# expenditure (currently only a simple average)
	def get_projected_accounts
		 #@projected_accounts_info = Hash[ACCOUNT_INFO.dup.find_all{|k,v| v[:discretionary]}]
		 #@projected_accounts_info = accounts_with_projections(@projected_accounts_info)
		 #@projected_accounts_info = @accounts.find_all{|acc| info = ACCOUNT_INFO[acc.name] and info[:discretionary]} 
    projected_accounts = @accounts.find_all{|acc| acc.info and acc.info[:discretionary]}
    @projected_accounts_info = accounts_with_projections(projected_accounts)
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
	# regular items that falls within the account period
	def sum_regular(regular_items, end_date, options={})
	  #end_date = @today + @days_ahead
		sum_out = regular_items.inject(0) do |sum, (account, item)|	
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



        #ep ['name2234', name, info, @projected_account_factor] if info[:discretionary]

        value + nunits * (info[:size]||account.projection*(@projected_account_factor||1.0))

			end
			sum_out + value
			#(rcp.excluding? and rcp.excluding.include?(name)) ? sum : sum + value
		end
		sum
	end
end
	include Analysis
end

# Some thoughts on double entry accounting: 
#
# assets - liabilities = equity
# where equity = equity_at_start + income - expenses
#
# so 
#
# assets - liabilities = equity_at_start + income - expenses
#
# or alternatively 
#
# assets + expenses = equity_at_start + income + liabilities (1)
#
# Good things:
# 	Positive equity_at_start, positive assets, positive income, negative liabilities, negative expenses
#
# A debit on the left of (1) must be matched by a credit on the right of (1) and 
# vice versa. 
#
#
# A debit to an asset account increases the value of the asset. This means buying some land
# or supplies or depositing some cash in a bank account. You can think of it as a debit because 
# you are locking up your equity in a way that may not be realisable. A credit to the asset account
# means drawing down on the asset, for example selling a bit of land or taking money out of a
# bank account.
#
# Similarly, a debit to an expense account, effectively, spending money on that expense,
# increases the value of that account. Debits here are clearly negative things from 
# the point of view of your wealth! (Credits to expense accounts would be something like
# travel reimbursements).
#
# A credit to income increases the value of the income account... this seems obvious. If
# you credit income you must debit assets (you have to put your income somewhere, for
# example a bank account, i.e. you must effectively spend it by buying an asset: remember
# a bank may fail... a bank account is an asset with risk just as much as a painting).
#
# A credit to liabilities increases the value of the liability, for example taking out a 
# loan. Once you credit a liability you have to either buy (debit) an asset, or buy (debit)
# an expense directly (for example a loan to pay some fees).
# 
# In any accounting period, the sum of all debits and credits should be 0. Also, at the end
# of the accounting period,
#
# equity_at_end = assets - liabilities = equity_at_start + income - expenses
#
# This seems obvious to me!!  
class Treasurer
class Reporter
	#include LocalCustomisations
	attr_reader :today
	def initialize(runner, options)
		@runner = runner
		@days_ahead = options[:days_ahead]||180
		@days_before = options[:days_before]||360
		@today = options[:today]||Date.today
		@start_date = @today - @days_before
		@runs = runner.component_run_list.values
		@indateruns = @runs.find_all{|r| r.days_ago(@today) < @days_before}
		p 'accounts256',@runs.size, @runs.map{|r| r.account}.uniq 
	
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
		sum = future_items.inject(0) do |sum, (name, item)| 
			item = [item] unless item.kind_of? Array
			value = item.inject(0) do |value,info|
				value += info[:size] unless (options[:today]||Date.today > info[:date]) or (info[:date] > end_date) # add unless we have already passed that date
				value
			end
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





				value + nunits * (info[:size]||info[:projection])

			end
			sum + value
			#(rcp.excluding? and rcp.excluding.include?(name)) ? sum : sum + value
		end
		sum
	end
	def report
		get_actual_budgets
		get_projected_budgets
	  @accounts = @runs.map{|r| r.account}.uniq.map{|acc| Account.new(acc, self, @runner, @runs, @projected_budgets, false)} + 
			@runs.map{|r| r.external_account}.uniq.map{|acc| Account.new(acc, self, @runner, @runs, @projected_budgets, true)} 
		@accounts.unshift Equity.new(self, @runner, @accounts)
		report = ""
		report << header
		report << '\begin{multicols}{2}'
		report << account_summaries
		report << account_balance_graphs
		report << expense_account_summary
		report << budget_expenditure_graphs
		report << '\end{multicols}'
		report << budget_resolutions
		report << budget_breakdown
		report << transactions_by_account
		report << footer

		File.open('report.tex', 'w'){|f| f.puts report}
		system "latex report.tex && latex report.tex"
	end
	class Account
		attr_reader :name, :external, :runs
		def initialize(name, reporter, runner, runs, projected_budgets, external)
			@name = name
			@reporter = reporter
			@runner = runner
			@projected_budgets =Hash[projected_budgets.find_all{|k,v| v[:account] == name}]
			@external = external
			@runs = runs.find_all{|r| (@external ? r.external_account : r.account) == name}
		end
		def type
			account_type(name)
		end
		def balance(date = @reporter.today) 
			#if !date
				#@runs.sort_by{|r| r.date}[-1].balance
			if @external
				@runs.find_all{|r| r.date < date}.map{|r| (r.deposit - r.withdrawal) * (@external ? -1 : 1)}.sum || 0.0
			else
				@runs.sort_by{|r| (r.date.to_datetime.to_time.to_i - date.to_datetime.to_time.to_i).to_f.abs}[0].balance
			end
		end
		def expenditure(today, days_before, &block)
			@runs.find_all{|r| r.days_ago(today) < days_before and (!block or yield(r)) }.map{|r| @external ? r.withdrawal : r.deposit }.sum || 0
		end
		def income(today, days_before)
			@runs.find_all{|r| r.days_ago(today) < days_before }.map{|r| @external ? r.deposit : r.withdrawal }.sum || 0
		end
		def summary_table(today, days_before)

			<<EOF
\\subsubsection{#{name}}
\\begin{tabulary}{0.8\\textwidth}{ r | l}
Balance & #{balance} \\\\
Deposited & #{expenditure(today, days_before)} \\\\
Withdrawn & #{income(today, days_before)} \\\\
\\end{tabulary}
EOF
		end
		def projected_balance(date)
			 balance - 
			 @reporter.sum_regular(REGULAR_EXPENDITURE[name], date) + 
			 @reporter.sum_regular(REGULAR_INCOME[name], date) -  
			 @reporter.sum_regular(@projected_budgets, date) -  
			 @reporter.sum_future(FUTURE_EXPENDITURE[name], date) + 
			 @reporter.sum_future(FUTURE_INCOME[name], date) + 
			 (REGULAR_TRANSFERS.keys.find_all{|from,to| to == name}.map{|key|
			 #p [acc, 'to', "key", key]
			 @reporter.sum_regular(REGULAR_TRANSFERS[key], date)
		 }.sum||0) - 
			 (REGULAR_TRANSFERS.keys.find_all{|from,to| from == name}.map{|key|
			 #p [acc, 'from',"key", key]
			 @reporter.sum_regular( REGULAR_TRANSFERS[key], date)
		 }.sum||0)  
		end
		# Write an eps graph to disk of past and projected
		# balance of the account
		def write_balance_graph(today, days_before, days_ahead)
			 #accshort = name.gsub(/\s/, '')
			 if not (@external or type == :Equity)
				 kit = @runner.graphkit(['date.to_time.to_i', 'balance'], {conditions: "account == #{name.inspect} and days_ago(Date.parse(#{today.to_s.inspect})) < #{days_before} and days_ago(Date.parse(#{today.to_s.inspect})) > -1", sort: 'date'})
			 else
				 pastdates = (today-days_before..today).to_a
				 balances = pastdates.map{|date| balance(date)}
				 kit = GraphKit.quick_create([pastdates.map{|d| d.to_time.to_i}, balances])
			 end
			 futuredates = (today..today+days_ahead).to_a
			 projection = futuredates.map{|date| projected_balance(date) }
			 kit2 = GraphKit.quick_create([futuredates.map{|d| d.to_time.to_i}, projection])
			 kit += kit2
			 kit.title = "Balance for #{name}"
			 kit.xlabel = %['Date' offset 0,-2]
			 kit.xlabel = nil
			 kit.ylabel = "Balance"

			 kit.data[0].gp.title = 'Previous'
			 kit.data[1].gp.title = '0 GBP Discretionary'
			 kit.data[1].gp.title = 'Projection'
			 kit.data.each{|dk| dk.gp.with = "lp"}

			 CodeRunner::Budget.kit_time_format_x(kit)

			 (kit).gnuplot_write("#{name}_balance.eps", size: "4.0in,3.0in")
		end
		# A string to include the balance graph in the document
		def balance_graph_string
			 #accshort = name.gsub(/\s/, '')
       "\\begin{center}\\includegraphics[width=3.0in]{#{name}_balance.eps}\\end{center}"
		end
	end
	class Equity < Account
		def initialize(reporter, runner, accounts)
			@reporter = reporter
			@runner = runner
			@accounts = accounts #.find_all{|acc| not acc.external}
		end
		def type
			:Equity
		end
		def name
			:Equity
		end
		def balance(date=@reporter.today)
			@accounts.map{|acc|
				case acc.type
				when :Asset
					acc.balance(date)
				when :Liability
					-acc.balance(date)
				else
					0.0
				end
			}.sum
		end
		def projected_balance(date=@reporter.today)
			@accounts.map{|acc|
				case acc.type
				when :Asset
					acc.projected_balance(date)
				when :Liability
					-acc.projected_balance(date)
				else
					0.0
				end
			}.sum
		end
		def summary_table(today, days_before)

			<<EOF
\\subsubsection{#{name}}
\\begin{tabulary}{0.8\\textwidth}{ r | l}
Balance & #{balance} \\\\
\\end{tabulary}
EOF
		end
	end
	def account_summaries
		#ep 'accounts', @accounts.map{|a| a.name}
		
		<<EOF
\\section{Summary of Accounts}
\\subsection{Equity}
#{@accounts.find{|acc| acc.type == :Equity }.summary_table(@today, @days_before)}
\\subsection{Assets}
#{@accounts.find_all{|acc| account_type(acc.name) == :Asset }.map{|acc| acc.summary_table(@today, @days_before)}.join("\n\n") }
\\subsection{Liabilities}
#{@accounts.find_all{|acc| account_type(acc.name) == :Liability }.map{|acc| acc.summary_table(@today, @days_before)}.join("\n\n") }
\\subsection{Income}
#{@accounts.find_all{|acc| account_type(acc.name) == :Income }.map{|acc| acc.summary_table(@today, @days_before)}.join("\n\n") }
\\subsection{Expenses}
#{@accounts.find_all{|acc| account_type(acc.name) == :Expense }.map{|acc| acc.summary_table(@today, @days_before)}.join("\n\n") }
EOF
	end
	def account_balance_graphs
		<<EOF
\\section{Graphs of Recent Balances}
#{@accounts.find_all{|acc| account_type(acc.name) != :Expense}.map{|acc|
 acc.write_balance_graph(@today, @days_before, @days_ahead)
 acc.balance_graph_string
}.join("\n\n")
}
EOF
	end
	def expense_account_summary
		<<EOF
\\section{Expense Account Summary}
\\subsection{Budget Period}
#{expense_pie_chart('budgetperiod'){|r| r.days_ago(@today) < @days_before}}
\\subsection{Last Week}
#{expense_pie_chart('lastweekexpenses'){|r| p ['r.daysago', r.days_ago(@today)]; r.days_ago(@today) < 7}}
\\subsection{Last Month}
#{expense_pie_chart('lastmonthexpenses'){|r| r.days_ago(@today) < 30}}
\\subsection{Last Year}
#{expense_pie_chart('lastyearexpenses'){|r| r.days_ago(@today) < 365}}
\\section{Expense Accounts by Budget}
#{@actual_budgets.map{|budget, budget_info|
	  "\\subsection{#{budget}}
		#{expense_pie_chart(budget + 'expenses'){|r|r.days_ago(@today) < @days_before and r.budget == budget}}"
}.join("\n\n")}

EOF
	end
	def expense_pie_chart(name, &block)
		expaccs = @accounts.find_all{|acc| account_type(acc.name) == :Expense}
		labels = expaccs.map{|acc| acc.name}
		exps = expaccs.map{|acc| acc.expenditure(@today, 50000, &block)}
		kit = GraphKit.quick_create([exps])
		kit.data[0].gp.with = 'boxes'
		kit.gp.style = "fill solid"
		pp ['kit222', kit, labels]
		i = -1
		kit.gp.xtics = "(#{labels.map{|l| %["#{l}" #{i+=1}]}.join(', ')}) rotate by 315"
		kit.gnuplot_write("#{name}.eps")

    "\\begin{center}\\includegraphics[width=3.0in]{#{name}.eps}\\vspace{1em}\\end{center}"
	end
	def budget_expenditure_graphs
		<<EOF
\\section{Budget Expenditure}
#{budget_and_transfer_graphs(@actual_budgets, {})}
EOF
	end
	def budget_and_transfer_graphs(budgets, options)
"#{budgets.map{|budget, budget_info| 
dates, expenditures, items = budget_expenditure(budget, budget_info)
#ep ['budget', budget, dates, expenditures]
kit = GraphKit.quick_create([dates.map{|d| d.to_time.to_i}, expenditures])
kit.data.each{|dk| dk.gp.with="boxes"}
kit.gp.style = "fill solid"
kit.xlabel = nil
kit.ylabel = "Expenditure"
unless options[:transfers]
 kits = budgets_with_averages({budget => budget_info}).map{|budget, budget_info| 
	 #ep 'Budget is ', budget
	 kit2 = GraphKit.quick_create([
			[dates[0], dates[-1]].map{|d| d.to_time.to_i}, 
			[budget_info[:average], budget_info[:average]]
	 ])
	 kit2.data[0].gp.with = 'lp lw 4'
	 kit2
	}
	#$debug_gnuplot = true
	#kits.sum.gnuplot
	kit += kits.sum

else
	kit.data[0].y.data.map!{|expen| expen*-1.0}
end
kit.title = "#{budget} Expenditure with average (Total = #{kit.data[0].y.data.sum})"
CodeRunner::Budget.kit_time_format_x(kit)
#kit.gnuplot
#ep ['kit1122', budget, kit]
kit.gnuplot_write("#{budget}.eps")
"\\begin{center}\\includegraphics[width=3.0in]{#{budget}.eps}\\vspace{1em}\\end{center}"
}.join("\n\n")
}"
	end

	def budget_resolutions
	  <<EOF
\\section{Budget Resolutions}

This section sums items from budgets drawn from an alternate account, i.e. it determines how much should be transferred from one account to another as a result of expenditure from a given budget.

#{@actual_budgets.map{|budget, budget_info|

"\\subsection{#{budget} }
		\\setlength{\\parindent}{0cm}\n\n\\begin{tabulary}{0.99\\textwidth}{r l}
			%\\hline
			Account Owed & Amount  \\\\
			\\hline
			\\Tstrut
  #{budget_items = @indateruns.find_all{|r| r.budget == budget}
    alternate_accounts = budget_items.map{|r| r.account}.uniq - [budget_info[:account]]
		alternate_accounts.map{|acc|
			alternate_items = budget_items.find_all{|r| r.account == acc}
			total = alternate_items.map{|r| r.withdrawal - r.deposit}.sum
			"#{acc} & #{total} \\\\"
		}.join("\n\n")
	}

			\\\\
			\\hline
			\\end{tabulary}
			\\normalsize
			\\vspace{1em}\n\n

#{	alternate_accounts.map{|acc|
			alternate_items = budget_items.find_all{|r| r.account == acc}
			alternate_items.pieces((alternate_items.size.to_f/50.to_f).ceil).map{|piece|
			"\\footnotesize\\setlength{\\parindent}{0cm}\n\n\\begin{tabulary}{0.99\\textwidth}{ #{"c " * 4 + " L " + " r " * 3 }}
			    #{budget}: & #{budget_info[:account]} & owes & #{acc} &&&&\\\\
					\\hline

					\\Tstrut

					#{piece.map{|r| 
					([:id] + CodeRunner::Budget.rcp.component_results - [:sc]).map{|res| 
							r.send(res).to_s.latex_escape
					#rcp.component_results.map{|res| r.send(res).to_s.gsub(/(.{20})/, '\1\\\\\\\\').latex_escape
						}.join(" & ")
					}.join("\\\\\n")
					}
			\\end{tabulary}\\normalsize"}.join("\n\n")
		}.join("\n\n")}
"
}.join("\n\n")
}
EOF
	end
	def budget_breakdown
		<<EOF
\\section{Budget and Transfer Breakdown}
#{(@actual_budgets).map{|budget, budget_info| 
	dates, expenditures, budget_items = budget_expenditure(budget, budget_info)
	#pp budget, budget_items.map{|items| items.map{|i| i.date.to_s}}
	"\\subsection{#{budget}}" + 
		budget_items.zip(dates, expenditures).map{|items, date, expenditure|
		if items.size > 0
			"
			\\footnotesize
			\\setlength{\\parindent}{0cm}\n\n\\begin{tabulary}{0.99\\textwidth}{ #{"c " * 4 + " L " + " r " * 2 }}
			%\\hline
			& #{date.to_s.latex_escape} & & & Total & #{expenditure} &  \\\\
			\\hline
			\\Tstrut
				#{items.map{|r| 
						([:id] + CodeRunner::Budget.rcp.component_results - [:sc, :balance]).map{|res| 
								r.send(res).to_s.latex_escape
							}.join(" & ")
						}.join("\\\\\n")
					}
			\\\\
			\\hline
			\\end{tabulary}
			\\normalsize
			\\vspace{1em}\n\n"
		else 
			""
		end
	}.join("\n\n")
}.join("\n\n")
}
EOF
	end

	def transactions_by_account
		<<EOF
\\section{Recent Transactions}
#{@accounts.find_all{|acc| not acc.type == :Equity}.sort_by{|acc| acc.external ? 0 : 1}.map{|acc| 
	"\\subsection{#{acc.name}}
\\footnotesize
#{all = acc.runs.find_all{|r|  r.days_ago(@today) < @days_before}.sort_by{|r| [r.date, r.id]}.reverse
#ep ['acc', acc, 'ids', all.map{|r| r.id}, 'size', all.size]
all.pieces((all.size.to_f/50.to_f).ceil).map{|piece|
"\\setlength{\\parindent}{0cm}\n\n\\begin{tabulary}{0.99\\textwidth}{ #{"c " * 4 + " L " + " r " * 3 + "l"}}
		#{piece.map{|r| 
	  ([:id] + CodeRunner::Budget.rcp.component_results - [:sc] + [:budget]).map{|res| r.send(res).to_s.latex_escape
	  #rcp.component_results.map{|res| r.send(res).to_s.gsub(/(.{20})/, '\1\\\\\\\\').latex_escape
  }.join(" & ")
}.join("\\\\\n")}
\\end{tabulary}"}.join("\n\n")}"
}.join("\n\n")}
EOF
	end

	def header
		<<EOF
\\documentclass{article}
\\usepackage[cm]{fullpage}
\\usepackage{tabulary}
\\usepackage{graphicx}
\\usepackage{multicol}
%\\usepackage{hyperlink}
\\newcommand\\Tstrut{\\rule{0pt}{2.8ex}}
\\begin{document}
\\title{#{@days_before}-day Budget Report}
\\maketitle
\\tableofcontents
EOF
	end
	def footer
		<<EOF
\\end{document}
EOF
	end

end
end

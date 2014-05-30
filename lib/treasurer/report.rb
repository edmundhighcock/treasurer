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
	attr_reader :in_limit_discretionary_budget_factor
	attr_reader :stable_discretionary_budget_factor
	attr_accessor :projected_budget_factor
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
	def report
		get_actual_budgets
		get_projected_budgets
	  @accounts = @runs.map{|r| r.account}.uniq.map{|acc| Account.new(acc, self, @runner, @runs, @projected_budgets, false)} + 
			@runs.map{|r| r.external_account}.uniq.map{|acc| Account.new(acc, self, @runner, @runs, @projected_budgets, true)} 
		@accounts.unshift (@equity = Equity.new(self, @runner, @accounts))
		get_in_limit_discretionary_budget_factor
		get_stable_discretionary_budget_factor
		report = ""
		report << header
		report << '\begin{multicols}{2}'
		report << account_summaries
		report << discretionary_budget_table
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
		def red_line(date)
			if Treasurer::LocalCustomisations.instance_methods.include? :red_line
				super(name, date)
			else 
				0.0
			end
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
		def money_in_sign
			case type
			when :Liability, :Income
				-1.0
			else
				1.0
			end
		end
		def projected_balance(date)
			 non_discretionary_projected_balance(date)  -
			 @reporter.sum_regular(@projected_budgets, date) 
		end
		def cache
			@cache ||={}
		end
		def non_discretionary_projected_balance(date)
			 cache[[:non_discretionary_projected_balance, date]] ||= 
				 balance - 
				 @reporter.sum_regular(REGULAR_EXPENDITURE[name], date) + 
				 @reporter.sum_regular(REGULAR_INCOME[name], date) -  
				 @reporter.sum_future(FUTURE_EXPENDITURE[name], date) + 
				 @reporter.sum_future(FUTURE_INCOME[name], date) + 
				 (FUTURE_TRANSFERS.keys.find_all{|from,to| to == name}.map{|key|
					 @reporter.sum_future(FUTURE_TRANSFERS[key], date) * money_in_sign
				 }.sum||0) - 
				 (FUTURE_TRANSFERS.keys.find_all{|from,to| from == name}.map{|key|
					 @reporter.sum_future( FUTURE_TRANSFERS[key], date) * money_in_sign
				 }.sum||0) +
				 (REGULAR_TRANSFERS.keys.find_all{|from,to| to == name}.map{|key|
					 @reporter.sum_regular(REGULAR_TRANSFERS[key], date) * money_in_sign
				 }.sum||0) - 
				 (REGULAR_TRANSFERS.keys.find_all{|from,to| from == name}.map{|key|
					 @reporter.sum_regular( REGULAR_TRANSFERS[key], date) * money_in_sign
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
			 red = futuredates.map{|date| red_line(date)}
			 kit3 = GraphKit.quick_create([futuredates.map{|d| d.to_time.to_i}, red])
			 @reporter.projected_budget_factor = @reporter.in_limit_discretionary_budget_factor
			 limit = futuredates.map{|date| projected_balance(date)}
			 kit4 = GraphKit.quick_create([futuredates.map{|d| d.to_time.to_i}, limit])
			 @reporter.projected_budget_factor = @reporter.stable_discretionary_budget_factor
			 #ep ['projected_budget_factor!!!!', @reporter.projected_budget_factor]
			 stable = futuredates.map{|date| projected_balance(date)}
			 kit5 = GraphKit.quick_create([futuredates.map{|d| d.to_time.to_i}, stable])
			 #exit
			 @projected_budget_factor = nil
			 kit += (kit2 + kit4 + kit5)
			 kit = kit3 + kit
			 kit.title = "Balance for #{name}"
			 kit.xlabel = %['Date' offset 0,-2]
			 kit.xlabel = nil
			 kit.ylabel = "Balance"

			 kit.data[0].gp.title = 'Limit'
			 kit.data[1].gp.title = 'Previous'
			 kit.data[2].gp.title = '0 GBP Discretionary'
			 kit.data[2].gp.title = 'Projection'
			 kit.data[3].gp.title = 'Limit'
			 kit.data[4].gp.title = 'Stable'
			 kit.data.each{|dk| dk.gp.with = "lp"}
			 kit.gp.key = ' bottom left '

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
		def red_line(date)
			@accounts.map{|acc|
				case acc.type
				when :Asset
					acc.red_line(date)
				when :Liability
					-acc.red_line(date)
				else
					0.0
				end
			}.sum
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
	def get_in_limit_discretionary_budget_factor
		@projected_budget_factor = 1.0
		loop do
			ok = true
			date = @today
			while date < @today + @days_ahead
				ok = false if @equity.projected_balance(date) < @equity.red_line(date)
				date += 1
				#ep ['projected_budget_factor', date, @equity.projected_balance(date),  @equity.red_line(date), ok]
			end
			@in_limit_discretionary_budget_factor = @projected_budget_factor
			break if (@projected_budget_factor == 0.0 or ok == true)
			@projected_budget_factor -= 0.01
			@projected_budget_factor -= 0.1
		end
		@projected_budget_factor = nil
		#exit
	end
	def get_stable_discretionary_budget_factor
		@projected_budget_factor = 1.0
		loop do
			ok = true
			date = @today
			balances = []
			while date < @today + @days_ahead
				#ok = false if @equity.projected_balance(date) < @equity.red_line(date)
				date += 1
				balances.push @equity.projected_balance(date)
				#ep ['projected_budget_factor', date, @equity.projected_balance(date),  @equity.red_line(date), ok]
			end
			ok = false if balances.mean < @equity.balance(@today)
			@stable_discretionary_budget_factor = @projected_budget_factor
			break if (@projected_budget_factor == 0.0 or ok == true)
			@projected_budget_factor -= 0.01
			@projected_budget_factor -= 0.1
		end
		@projected_budget_factor = nil
		#exit
	end
	def discretionary_budget_table
		discretionary_budgets = budgets_with_averages(@projected_budgets)

		<<EOF
\\section{Discretionary Budget Summary}
\\begin{tabulary}{0.5\\textwidth}{ R | c  c  c c  }
Budget & Average & Projection & Limit & Stable \\\\
#{discretionary_budgets.map{|budget, info|
		#ep info
		"#{budget} & #{info[:average]} & #{info[:projection]} & #{
        (info[:projection] * @in_limit_discretionary_budget_factor).round(2)} & 
        #{(info[:projection] * @stable_discretionary_budget_factor).round(2)}  \\\\"
  }.join("\n\n")
}
\\end{tabulary}
EOF
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

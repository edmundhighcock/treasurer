class Float
	def to_s
		sprintf("%.2f", self)
	end
end
class Date
	def inspect
		"Date.parse('#{to_s}')"
	end
end
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
	attr_reader :in_limit_discretionary_account_factor
	attr_reader :stable_discretionary_account_factor
	attr_accessor :projected_account_factor
	attr_reader :equity
	attr_reader :projected_accounts_info
	attr_reader :days_before 
	def initialize(runner, options)
		@runner = runner
		@days_ahead = options[:days_ahead]||180
		@days_before = options[:days_before]||360
		@today = options[:today]||Date.today
		@start_date = @today - @days_before
		@runs = runner.component_run_list.values

		if run = @runs.find{|r| not r.external_account}
			raise "External_account not specified for #{run.data_line}" 
		end
		@indateruns = @runs.find_all{|r| r.days_ago(@today) < @days_before}
		#p 'accounts256',@runs.size, @runs.map{|r| r.account}.uniq 
	
	end
	def report
		#get_actual_accounts
	  accounts = @runs.map{|r| r.account}.uniq.map{|acc| Account.new(acc, self, @runner, @runs, false)} 
	  external_accounts = (@runs.map{|r| r.external_account}.uniq - accounts.map{|acc| acc.name}).map{|acc| Account.new(acc, self, @runner, @runs, true)} 
		@accounts = accounts + external_accounts
		@expense_accounts = @accounts.find_all{|acc| acc.type == :Expense}
		get_projected_accounts
		#p ['projected_accounts_info', @projected_accounts_info]
		#exit
		@accounts.unshift (@equity = Equity.new(self, @runner, @accounts))
		get_in_limit_discretionary_account_factor
		get_stable_discretionary_account_factor
		report = ""
		report << header
		report << '\begin{multicols}{2}'
		report << account_summaries
		report << discretionary_account_table
		report << account_balance_graphs
		report << expense_account_summary
		report << account_expenditure_graphs
		report << '\end{multicols}'
		##report << account_resolutions
		#report << account_breakdown
		
		report << assumptions
		report << transactions_by_account
		report << footer

		File.open('report.tex', 'w'){|f| f.puts report}
		system "latex report.tex && latex report.tex"
	end
	class Account
	end
	class SubAccount < Account
		def initialize(name, reporter, runner, runs, external)
			@name = name
			@reporter = reporter
			@runner = runner
			#@projected_accounts_info =Hash[projected_accounts_info.find_all{|k,v| v[:account] == name}]
			@external = external
			@runs = runs.find_all{|r| r.sub_account  == name}
			#ep ['sub_accounts333', name, @runs.size, runs.size]
		end
	end
	class Account
		attr_reader :name, :external, :runs
		def initialize(name, reporter, runner, runs, external)
			@name = name
			@reporter = reporter
			@runner = runner
			#@projected_accounts_info =Hash[projected_accounts_info.find_all{|k,v| v[:account] == name}]
			@external = external
			@runs = runs.find_all{|r| (@external ? r.external_account : r.account) == name}
		end
		def sub_accounts
			@sub_accounts ||= @runs.map{|r| r.sub_account}.uniq.compact.map{|acc| SubAccount.new(acc, @reporter, @runner, @runs, @external)}
		end
		def type
			#account_type(name)
			if ACCOUNT_INFO[name] and type = ACCOUNT_INFO[name][:type]
				type
			else
				:Expense
			end
		end
		def red_line(date)
			if Treasurer::LocalCustomisations.instance_methods.include? :red_line
				super(name, date)
			else 
				0.0
			end
		end
		def report_start
			@reporter.today - @reporter.days_before
	  end
		def opening_date
			(info && info[:start]) || report_start
		end
		def balance(date = @reporter.today) 
			#if !date
				#@runs.sort_by{|r| r.date}[-1].balance
			if @external
				#p ['name is ', name, type]
				#
				@runs.find_all{|r| r.date <= date and r.date >= opening_date }.map{|r| money_in_sign * (r.deposit - r.withdrawal) * (@external ? -1 : 1)}.sum || 0.0
				 #Temporary....
				#0.0
			else
				@runs.sort_by{|r| (r.date.to_datetime.to_time.to_i - date.to_datetime.to_time.to_i).to_f.abs}[0].balance
			end
		end
		def deposited(today, days_before, &block)
				p ['name22 is ', name, type, @runs.size]
			@runs.find_all{|r| r.days_ago(today) < days_before and (!block or yield(r)) }.map{|r| (@external ^ ([:Liability, :Income].include?(type))) ? r.withdrawal : r.deposit }.sum || 0
		end
		def withdrawn(today, days_before)
			@runs.find_all{|r| r.days_ago(today) < days_before }.map{|r| (@external ^ ([:Liability, :Income].include?(type))) ? r.deposit : r.withdrawal }.sum || 0
		end
		
		def summary_table(today, days_before)

			<<EOF
\\subsubsection{#{name}}
\\begin{tabulary}{0.8\\textwidth}{ r | l}
Balance & #{balance} \\\\
Deposited & #{deposited(today, days_before)} \\\\
Withdrawn & #{withdrawn(today, days_before)} \\\\
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
		def discretionary
			info and info[:discretionary]
		end
		def info
			ACCOUNT_INFO[name]
		end
		def projected_balance(date)
			 #return 0.0 if @external # Temporary Hack
			 #ep ['projected', @reporter.projected_accounts_info]
			 raise "Only should be called for Asset and Liability accounts" unless [:Asset, :Liability].include? type
			 non_discretionary_projected_balance(date)  -
			 @reporter.sum_regular(linked_projected_account_info, date)
			 
			 #(discretionary ? @reporter.sum_regular({name => info}, date) : 0.0)
		end
		def linked_projected_account_info
			Hash[@reporter.projected_accounts_info.find_all{|ac,inf| inf[:linked_account] == name}]
		end
		def cache
			@cache ||={}
		end
		def non_discretionary_projected_balance(date)
			 #ep ['FUTURE_INCOME', FUTURE_INCOME, name] if FUTURE_INCOME.size > 0
			 cache[[:non_discretionary_projected_balance, date]] ||= 
				 balance +
				 #@reporter.sum_regular(REGULAR_EXPENDITURE[name], date) + 
				 #@reporter.sum_regular(REGULAR_INCOME[name], date) -  
				 #@reporter.sum_future(FUTURE_EXPENDITURE[name], date) + 
				 #@reporter.sum_future(FUTURE_INCOME[name], date) + 
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
				 kit = @runner.graphkit(['date.to_time.to_i', 'balance'], {conditions: "account == #{name.inspect} and days_ago(Date.parse(#{today.to_s.inspect})) < #{days_before} and days_ago(Date.parse(#{today.to_s.inspect})) > -1", sort: '[date, id]'})
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
			 @reporter.projected_account_factor = @reporter.in_limit_discretionary_account_factor
			 limit = futuredates.map{|date| projected_balance(date)}
			 kit4 = GraphKit.quick_create([futuredates.map{|d| d.to_time.to_i}, limit])
			 @reporter.projected_account_factor = @reporter.stable_discretionary_account_factor
			 #ep ['projected_account_factor!!!!', @reporter.projected_account_factor]
			 stable = futuredates.map{|date| projected_balance(date)}
			 kit5 = GraphKit.quick_create([futuredates.map{|d| d.to_time.to_i}, stable])
			 #exit
			 @reporter.projected_account_factor = nil
			 kit += (kit2 + kit4 + kit5)
			 #kit += (kit2)
			 kit = kit3 + kit
			 kit.title = "Balance for #{name}"
			 kit.xlabel = %['Date' offset 0,-2]
			 kit.xlabel = nil
			 kit.ylabel = "Balance"

			 kit.data[0].gp.title = 'Limit'
			 kit.data[1].gp.title = 'Previous'
			 kit.data[2].gp.title = '0 GBP Discretionary'
			 kit.data[2].gp.title = 'Projection'
			 #kit.data[3].gp.title = 'Limit'
			 #kit.data[4].gp.title = 'Stable'
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
#{@accounts.find_all{|acc| acc.type == :Asset }.map{|acc| acc.summary_table(@today, @days_before)}.join("\n\n") }
\\subsection{Liabilities}
#{@accounts.find_all{|acc| acc.type == :Liability }.map{|acc| acc.summary_table(@today, @days_before)}.join("\n\n") }
\\subsection{Income}
#{@accounts.find_all{|acc| acc.type == :Income }.map{|acc| acc.summary_table(@today, @days_before)}.join("\n\n") }
\\subsection{Expenses}
#{@accounts.find_all{|acc| acc.type == :Expense }.map{|acc| acc.summary_table(@today, @days_before)}.join("\n\n") }
EOF
	end
	def account_balance_graphs
		<<EOF
\\section{Graphs of Recent Balances}
#{[:Equity, :Asset, :Liability].map{|typ|
 "\\subsection{#{typ}}" + 
 @accounts.find_all{|acc| acc.type == typ}.map{|acc|
	 acc.write_balance_graph(@today, @days_before, @days_ahead)
	 acc.balance_graph_string
	}.join("\n\n")
}.join("\n\n")
}
EOF
	end
	def expense_account_summary
		<<EOF
\\section{Expense Account Summary}
\\subsection{Budget Period}
#{expense_pie_chart('accountperiod', @expense_accounts){|r| r.days_ago(@today) < @days_before}}
\\subsection{Last Week}
#{expense_pie_chart('lastweekexpenses', @expense_accounts){|r| p ['r.daysago', r.days_ago(@today)]; r.days_ago(@today) < 7}}
\\subsection{Last Month}
#{expense_pie_chart('lastmonthexpenses', @expense_accounts){|r| r.days_ago(@today) < 30}}
\\subsection{Last Year}
#{expense_pie_chart('lastyearexpenses', @expense_accounts){|r| r.days_ago(@today) < 365}}
\\section{Expense Account Breakdown}
#{@expense_accounts.map{|account|
		#ep ['sub_accounts2124', account.sub_accounts.map{|sa| sa.name}]
	  "\\subsection{#{account.name}} + 
		#{expense_pie_chart(account.name + 'breakdown', account.sub_accounts){|r|r.days_ago(@today) < @days_before }}"
}.join("\n\n")}
EOF

#EOF
	end
	def expense_pie_chart(name, accounts, &block)
		#expaccs = accounts.find_all{|acc| acc.type == :Expense}
		labels = accounts.map{|acc| acc.name}
		exps = accounts.map{|acc| acc.deposited(@today, 50000, &block)}
		labels, exps = [labels, exps].transpose.find_all{|l, e| e != 0.0}.transpose
		#ep ['labels22539', name, labels, exps]
		return "No expenditure in account period." if labels == nil
		kit = GraphKit.quick_create([exps])
		kit.data[0].gp.with = 'boxes'
		kit.gp.style = "fill solid"
		#pp ['kit222', kit, labels]
		i = -1
		kit.gp.xtics = "(#{labels.map{|l| %["#{l}" #{i+=1}]}.join(', ')}) rotate by 315"
		kit.gnuplot_write("#{name}.eps")

    "\\begin{center}\\includegraphics[width=3.0in]{#{name}.eps}\\vspace{1em}\\end{center}"
	end
	def get_in_limit_discretionary_account_factor
		@projected_account_factor = 1.0
		loop do
			ok = true
			date = @today
			while date < @today + @days_ahead
				ok = false if @equity.projected_balance(date) < @equity.red_line(date)
				date += 1
				#ep ['projected_account_factor', date, @equity.projected_balance(date),  @equity.red_line(date), ok]
			end
			@in_limit_discretionary_account_factor = @projected_account_factor
			break if (@projected_account_factor == 0.0 or ok == true)
			@projected_account_factor -= 0.01
			@projected_account_factor -= 0.1
			ep ['projected_account_factor', @projected_account_factor]
		end
		@projected_account_factor = nil
		#exit
	end
	def get_stable_discretionary_account_factor
		@projected_account_factor = 1.0
		loop do
			ok = true
			date = @today
			balances = []
			while date < @today + @days_ahead
				#ok = false if @equity.projected_balance(date) < @equity.red_line(date)
				date += 1
				balances.push @equity.projected_balance(date)
				#ep ['projected_account_factor', date, @equity.projected_balance(date),  @equity.red_line(date), ok]
			end
			ok = false if balances.mean < @equity.balance(@today)
			@stable_discretionary_account_factor = @projected_account_factor
			break if (@projected_account_factor == 0.0 or ok == true)
			@projected_account_factor -= 0.01
			@projected_account_factor -= 0.1
		end
		@projected_account_factor = nil
		#exit
	end
	def discretionary_account_table
		discretionary_accounts = accounts_with_averages(@projected_accounts_info)

		<<EOF
\\section{Discretionary Budget Summary}
\\begin{tabulary}{0.5\\textwidth}{ R | c  c  c c  }
Budget & Average & Projection & Limit & Stable \\\\
#{discretionary_accounts.map{|account, info|
		#ep info
		"#{account} & #{info[:average]} & #{info[:projection]} & #{
        (info[:projection] * @in_limit_discretionary_account_factor).round(2)} & 
        #{(info[:projection] * @stable_discretionary_account_factor).round(2)}  \\\\"
  }.join("\n\n")
}
\\end{tabulary}
EOF
	end
	def account_expenditure_graphs
		<<EOF
\\section{Expenditure by Account Period}
#{account_and_transfer_graphs(Hash[@expense_accounts.find_all{|acc| acc.info and acc.info[:period]}.map{|acc| [acc.name, acc.info]}], {})}
EOF
	end
	def account_and_transfer_graphs(accounts, options)
"#{accounts.map{|account, account_info| 
#ep ['accountbadf', account, account_info]
	dates, expenditures, items = account_expenditure(account, account_info)
if dates.size == 0
	""
else
	#ep ['account', account, dates, expenditures]
	kit = GraphKit.quick_create([dates.map{|d| d.to_time.to_i}, expenditures])
	kit.data.each{|dk| dk.gp.with="boxes"}
	kit.gp.style = "fill solid"
	kit.xlabel = nil
	kit.ylabel = "Expenditure"
	unless options[:transfers]
	 kits = accounts_with_averages({account => account_info}).map{|account, account_info| 
		 #ep 'Budget is ', account
		 kit2 = GraphKit.quick_create([
				[dates[0], dates[-1]].map{|d| d.to_time.to_i}, 
				[account_info[:average], account_info[:average]]
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
	kit.title = "#{account} Expenditure with average (Total = #{kit.data[0].y.data.sum})"
	CodeRunner::Budget.kit_time_format_x(kit)
	#kit.gnuplot
	#ep ['kit1122', account, kit]
	kit.gnuplot_write("#{account}.eps")
	"\\begin{center}\\includegraphics[width=3.0in]{#{account}.eps}\\vspace{1em}\\end{center}"
end
}.join("\n\n")
}"
	end

	def account_resolutions
	  <<EOF
\\section{Budget Resolutions}

This section sums items from accounts drawn from an alternate account, i.e. it determines how much should be transferred from one account to another as a result of expenditure from a given account.

#{@actual_accounts.map{|account, account_info|

"\\subsection{#{account} }
		\\setlength{\\parindent}{0cm}\n\n\\begin{tabulary}{0.99\\textwidth}{r l}
			%\\hline
			Account Owed & Amount  \\\\
			\\hline
			\\Tstrut
  #{account_items = @indateruns.find_all{|r| r.account == account}
    alternate_accounts = account_items.map{|r| r.account}.uniq - [account_info[:account]]
		alternate_accounts.map{|acc|
			alternate_items = account_items.find_all{|r| r.account == acc}
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
			alternate_items = account_items.find_all{|r| r.account == acc}
			alternate_items.pieces((alternate_items.size.to_f/50.to_f).ceil).map{|piece|
			"\\footnotesize\\setlength{\\parindent}{0cm}\n\n\\begin{tabulary}{0.99\\textwidth}{ #{"c " * 4 + " L " + " r " * 3 }}
			    #{account}: & #{account_info[:account]} & owes & #{acc} &&&&\\\\
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
	def assumptions
	  <<EOF
		\\section{Assumptions for Projection}
		\\subsection{Regular Transfers}
		\\begin{lstlisting}[language=ruby]
#{REGULAR_TRANSFERS.pretty_inspect.latex_escape}
		\\end{lstlisting}
		\\subsection{One-off Transfers}
		\\begin{lstlisting}[language=ruby]
#{FUTURE_TRANSFERS.pretty_inspect.latex_escape}
		\\end{lstlisting}
EOF
	end
	def account_breakdown
		<<EOF
\\section{SubAccount Breakdown}
#{(@actual_accounts).map{|account, account_info| 
	dates, expenditures, account_items = account_expenditure(account, account_info)
	#pp account, account_items.map{|items| items.map{|i| i.date.to_s}}
	"\\subsection{#{account}}" + 
		account_items.zip(dates, expenditures).map{|items, date, expenditure|
		if items.size > 0
			"
			\\footnotesize
			\\setlength{\\parindent}{0cm}\n\n\\begin{tabulary}{0.99\\textwidth}{ #{"c " * 3 + " L " + " r " * 2 + " c " }}
			%\\hline
			#{date.to_s.latex_escape} & & & Total & #{expenditure} &  \\\\
			\\hline
			\\Tstrut
				#{items.map{|r| 
						( CodeRunner::Budget.rcp.component_results + [:external_account] -  [:sc, :balance ]).map{|res| 
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
"\\setlength{\\parindent}{0cm}\n\n\\begin{tabulary}{0.99\\textwidth}{ #{"c " * 3 + " L " + " r " * 3 + "l"}}
		#{piece.map{|r| 
	  (CodeRunner::Budget.rcp.component_results - [:sc] + [:sub_account]).map{|res| r.send(res).to_s.latex_escape
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
\\usepackage{hyperref}
\\usepackage{xcolor,listings}
\\newcommand\\Tstrut{\\rule{0pt}{2.8ex}}
\\lstset{%
basicstyle=\\ttfamily\\color{black},
identifierstyle = \\ttfamily\\color{purple},
keywordstyle=\\ttfamily\\color{blue},
stringstyle=\\color{orange}}
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

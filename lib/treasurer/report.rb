require 'active_support/core_ext/integer/inflections'

class Array
  def median
    self.sort[size/2 + size%2]
  end
end

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
    attr_reader :today, :start_date, :end_date
    attr_reader :in_limit_discretionary_account_factors
    attr_reader :stable_discretionary_account_factors
    attr_accessor :projected_account_factor
    attr_reader :accounts
    attr_reader :equity
    attr_reader :projected_accounts_info
    attr_reader :days_before 
    attr_reader :report_currency
    attr_reader :accounts_hash
    def initialize(runner, options)
      @runner = runner
      @days_ahead = options[:days_ahead]||180
      @days_before = options[:days_before]||360
      @today = options[:today]||Date.today
      @start_date = @today - @days_before
      @end_date = @today + @days_ahead
      @runs = runner.component_run_list.values
      @currencies = ACCOUNT_INFO.map{|k,v| v[:currencies]}.flatten.uniq
      @report_currency = options[:report_currency]

      if run = @runs.find{|r| not r.external_account}
        raise "External_account not specified for #{run.data_line}" 
      end
      @indateruns = @runs.find_all{|r| r.days_ago(@today) < @days_before}
      @stable_discretionary_account_factors = {}
      @in_limit_discretionary_account_factors = {}
      #p 'accounts256',@runs.size, @runs.map{|r| r.account}.uniq 

    end
    def generate_accounts
      accounts = @runs.map{|r| r.account}.uniq.map{|acc| Account.new(acc, self, @runner, @runs, false)} 
      external_accounts = (@runs.map{|r| r.external_account}.uniq - accounts.map{|acc| acc.name}).map{|acc| Account.new(acc, self, @runner, @runs, true)} 
      #if not @report_currency
        external_accounts = external_accounts.map do |acc|
          if acc_inf = ACCOUNT_INFO[acc.name] and currencies = acc_inf[:currencies] and currencies.size > 1
            raise "Only expense accounts can have multiple currencies: #{acc.name} has type #{acc.type}" unless acc.type == :Expense
            new_accounts = currencies.map do |curr|
              Account.new(acc.name, self, @runner, @runs, true, currency: curr)
            end
            new_accounts.delete_if{|a| a.runs.size == 0}
            new_accounts
          else
            acc
          end
        end
      #end
      external_accounts = external_accounts.flatten
      @accounts = accounts + external_accounts
      @expense_accounts = @accounts.find_all{|acc| acc.type == :Expense}
      @accounts_hash = @accounts.map{|acc| [acc.name, acc]}.to_h

      if @report_currency
        @runs.each do |r|
          if (curr = @accounts_hash[r.account].currency) != @report_currency
            er = EXCHANGE_RATES[[curr, @report_currency]]
            r.deposit *= er
            r.withdrawal *= er
            r.balance *= er if r.has_balance?
          end
        end
        ASSETS.each do |name, details|
          details[:size] *= EXCHANGE_RATES[[details[:currency], @report_currency]] if details[:currency]!=@report_currency
          details[:currency] = @report_currency
        end
        [REGULAR_TRANSFERS, FUTURE_TRANSFERS].each do |transfers|
          transfers.each do |accs, trans|
            #acc = accs.find{|a| p a, @accounts_hash.keys, @accounts.map{|ac| ac.name}; not @accounts_hash[a].external}
            trans.each do |item, details|
              if details[:currency] != @report_currency
                #p item, acc, curr, @report_currency
                details[:size] *= EXCHANGE_RATES[[details[:currency], @report_currency]]
                details[:currency] = @report_currency
              end
            end
          end
        end
        @accounts.each do |acc|
          if acc.info[:opening_balance]
            if acc.currency != @report_currency
              acc.info[:opening_balance] *= EXCHANGE_RATES[[acc.currency, @report_currency]]
            end
          end
          acc.instance_variable_set(:@original_currency, acc.currency)
          acc.instance_variable_set(:@currency, @report_currency)
          acc.info[:currencies] = [@report_currency]
        end

      end
      get_projected_accounts
      #p ['projected_accounts_info', @projected_accounts_info]
      #exit
      @equities = currency_list.map do |currency|
        equity = Equity.new(self, @runner, @accounts.find_all{|acc| acc.currency == currency}, currency: currency)
        @accounts.unshift (equity)
        [currency, equity]
      end
      @equities = @equities.to_h
    end
     
    def report
      generate_accounts
      #get_actual_accounts
      currency_list.each do |currency|
        get_in_limit_discretionary_account_factor(currency)
        get_stable_discretionary_account_factor(currency)
      end
      report = ""
      report << header
      #report << '\begin{multicols}{2}'
      report << account_summaries
      currency_list.each do |currency|
        report << discretionary_account_table(currency)
      end
      report << account_balance_graphs
      report << expense_account_summary
      report << account_expenditure_graphs
      #report << '\end{multicols}'
      ##report << account_resolutions
      #report << account_breakdown

      report << assumptions
      report << transactions_by_account
      report << footer

      File.open('report.tex', 'w'){|f| f.puts report}
      system "lualatex report.tex && lualatex report.tex"
    end
    def account_summaries
      #ep 'accounts', @accounts.map{|a| a.name}

      <<EOF
\\section{Summary of Accounts}
      #{[:Equity, :Asset, :Liability, :Income, :Expense].map{|type|
      accs = @accounts.find_all{|acc| acc.type == type }
      "\\subsection{#{type}}
    \\begin{tabulary}{0.9\\textwidth}{ R | c | c | c}
    Account & Balance & Deposited & Withdrawn \\\\
    \\hline
    \\Tstrut
      #{(accs.map{|acc| acc.summary_line(@today, @days_before)} + 
      (type == :Asset ? ASSETS.map{|n,details| "#{n} (#{details[:currency]}) & #{details[:size]} & & "} : [])).join("\\\\\n")}
      #{type!=:Equity&&false ? "
      \\\\ \\hline
      \\Tstrut
      Totals & #{accs.map{|a| a.balance}.sum} & #{accs.map{|a| a.deposited(@today, @days_before)}.sum} & #{accs.map{|a| a.withdrawn(@today, @days_before)}.sum} \\\\ " : "\\\\"}
    \\end{tabulary}"
      }.join("\n\n")}
EOF
    end
    def account_balance_graphs
      <<EOF
\\section{Graphs of Recent Balances}
      #{[:Equity, :Asset, :Liability].map{|typ|
      "\\subsection{#{typ}}\\vspace{3em}" + 
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
\\subsection{Totals for #@days_before-day Budget Period}
      #{expense_pie_charts_by_currency('accountperiod', @expense_accounts){|r| r.days_ago(@today) < @days_before}}
\\subsection{Expense Account Breakdown}
      #{@expense_accounts.map{|account|
      #ep ['sub_accounts2124', account.sub_accounts.map{|sa| sa.name}]
      "\\subsection{#{account.name_c}} 
      #{expense_pie_chart(account.name_c_file + 'breakdown', account.sub_accounts, account){|r|r.days_ago(@today) < @days_before }}"
      }.join("\n\n")}
EOF

      #EOF
    end
    def currency_list(accounts=@accounts, &block)
      p accounts.map{|acc| acc.name rescue nil}
      if block_given?
        accounts.find_all{|acc| acc.runs.find{|r| yield(r)}}.map{|acc| acc.currency}.uniq.compact
      else
        accounts.find_all{|acc| not acc.runs or acc.runs.find{|r| r.in_date(acc.info)}}.map{|acc| acc.currency}.uniq.compact
      end
    end

    def expense_pie_charts_by_currency(name, accounts, &block)
      currencies = currency_list(accounts, &block)
      return (
        currencies.map do |curr|
          str = ""
          str << "\\subsubsection{#{curr}}\n" if curr
          str << expense_pie_chart(name + curr.to_s, accounts.find_all{|acc| acc.currency == curr}, &block)
          str
        end
      ).join("\n\n")
    end
    def expense_pie_chart(name, accounts, subacc=nil, &block)
      #expaccs = accounts.find_all{|acc| acc.type == :Expense}
      labels = accounts.map{|acc| acc.name}
      #ep ['labels22539', name, labels, exps]

      kit = if subacc
        start_dates, end_dates, _exps, _items = account_expenditure(subacc)
        end_dates = end_dates.reverse #Now from earliest to latest
        start_dates = start_dates.reverse
        pp ['DATES', start_dates, end_dates, subacc.name]
        return "No expenditure in account period." if end_dates.size==0
        k = (
          end_dates.size.times.map do |i|
            exps = accounts.map{|acc| acc.deposited(end_dates[i], end_dates[i] - start_dates[i], &block)}
            kt = GraphKit.quick_create([labels.size.times.to_a.map{|l| l.to_f + i.to_f/end_dates.size.to_f}, exps])
            kt.data[0].gp.title = "Ending #{end_dates[i].strftime("#{end_dates[i].mday.ordinalize} %B")}; total = #{exps.sum}"
            kt.gp.key = "tmargin"
            kt
          end
        ).sum
        k
      else
        exps = accounts.map{|acc| acc.deposited(@today, 50000, &block)}
        labels, exps = [labels, exps].transpose.find_all{|l, e| e != 0.0}.transpose
        return "No expenditure in account period." if not labels #<F8> labels.size==0
        GraphKit.quick_create([labels.size.times.to_a, exps])
      end


      #sum = exps.sum
      #angles = exps.map{|ex| ex/sum * 360.0}
      #start_angles = angles.dup #inject(-angles[0]){|o,n| o+n}
      ##start_angles.map!{|a| a+(start_angles
      #end_angles = angles.inject(-angles[0]){|o,n| o+n}


      kit.data.each{|dk| dk.gp.with = 'boxes'}
      kit.gp.boxwidth = "#{0.8/kit.data.size} absolute"
      kit.gp.style = "fill solid"
      kit.gp.yrange = "[#{[kit.data[0].y.data.min,0].min}:]"
      #kit.gp.xrange = "[-1:#{labels.size+1}]"
      kit.gp.xrange = "[-1:1]" if labels.size==1
      kit.gp.grid = "ytics"
      kit.xlabel = nil
      kit.ylabel = nil
      i = -1
      kit.gp.xtics = "(#{labels.map{|l| %["#{l}" #{i+=1}]}.join(', ')}) rotate by 315"
      pp ['kit222', kit, labels]
      fork do 
        kit.gnuplot_write("#{name}.eps", size: "4.0in,2.0in")
        %x[epspdf #{name}.eps]
      end

      #"\\begin{center}\\includegraphics[width=3.0in]{#{name}.eps}\\vspace{1em}\\end{center}"
      #"\\begin{center}\\includegraphics[width=0.9\\textwidth]{#{name}.eps}\\vspace{1em}\\end{center}"
      "\\myfigure{#{name}.pdf}"
    end
    def get_in_limit_discretionary_account_factor(currency)
      @projected_account_factor = 1.0
      loop do
        ok = true
        date = @today
        while date < @today + @days_ahead
          ok = false if @equities[currency].projected_balance(date) < @equities[currency].red_line(date)
          date += 1
          #ep ['projected_account_factor', date, @equity.projected_balance(date),  @equity.red_line(date), ok]
        end
        @in_limit_discretionary_account_factors[currency] = @projected_account_factor
        ep ['projected_account_factor', @projected_account_factor, @equities[currency].projected_balance(date), currency, ok]
        break if (@projected_account_factor <= 0.0 or ok == true)
        @projected_account_factor -= 0.01
        @projected_account_factor -= 0.04
      end
      @projected_account_factor = nil
      #exit
    end
    def get_stable_discretionary_account_factor(currency)
      @projected_account_factor = 1.0
      loop do
        ok = true
        date = @today
        balances = []
        while date < @today + @days_ahead
          #ok = false if @equity.projected_balance(date) < @equity.red_line(date)
          date += 1
          balances.push @equities[currency].projected_balance(date)
          #ep ['projected_account_factor', date, balances.mean, @projected_account_factor,  @equities[currency].balance(@today), ok]
        end
        ok = false if balances.mean < @equities[currency].balance(@today) - 0.001
        #ok = false if balances.median < @equities[currency].balance(@today) - 0.001
        @stable_discretionary_account_factors[currency] = @projected_account_factor
        break if (@projected_account_factor <= 0.0 or ok == true)
        @projected_account_factor -= 0.01
        #@projected_account_factor -= 0.1
      end
      @projected_account_factor = nil
      #exit
    end
    def discretionary_account_table(currency)
      discretionary_accounts = accounts_with_averages(@projected_accounts_info.find_all{|acc,inf| acc.currency == currency}.to_h)

      <<EOF
\\section{Discretionary Budget Summary (#{currency})}
\\begin{tabulary}{0.9\\textwidth}{ R | c  c  c c  }
Budget & Average & Projection & Limit & Stable \\\\
      #{discretionary_accounts.map{|account, info|
      #ep info
      "#{account.name_c} & #{account.average} & #{account.projection} & #{
        (account.projection * @in_limit_discretionary_account_factors[currency]).round(2)} & 
      #{(account.projection * @stable_discretionary_account_factors[currency]).round(2)}  \\\\"
      }.join("\n\n")
      }
\\end{tabulary}
EOF
    end
    def account_expenditure_graphs
      <<EOF
\\section{Expenditure by Account Period}
      #{currency_list.map{|curr| 
        account_and_transfer_graphs(@expense_accounts.find_all{|acc| 
          acc.info and acc.info[:period] and acc.currency == curr
        })
      }.join("\n")}
EOF
    end
    def account_and_transfer_graphs(accounts, options={})
      "#{accounts.map{|account| 
        account_info = account.info
        #ep ['accountbadf', account, account_info]
        start_dates, dates, expenditures, _items = account_expenditure(account)
        ep ['accountbadf', account.name_c, account_info, expenditures]
        if dates.size == 0
          ""
        else
          #ep ['account', account, dates, expenditures]
          plotdates = dates.zip(start_dates).map{|d, s| (d.to_time.to_i + s.to_time.to_i)/2.0}
          kit = GraphKit.quick_create([plotdates, expenditures])
          kit.data.each{|dk| dk.gp.with="boxes"}
          kit.gp.style = "fill solid"
          kit.xlabel = nil
          kit.ylabel = "Expenditure"
          kit.data[0].gp.with = 'boxes'
          dat = kit.data[0].x.data
          barsize = (dat.max.to_f  - dat.min.to_f)/dat.size * 0.8
          kit.gp.boxwidth = "#{barsize} absolute"
          dat.map!{|d| d - barsize*1.1}
          kit.gp.yrange = "[#{[kit.data[0].y.data.min,0].min}:]"
          #kit.gp.xrange = "[-1:#{labels.size+1}]"
          #kit.gp.xrange = "[-1:1]" if labels.size==1
          kit.gp.grid = "ytics"
          kit.xlabel = nil
          kit.ylabel = nil
          unless options[:transfers]
            kits = accounts_with_averages({account => account_info}).map{|account, account_info| 
              #ep 'Budget is ', account
              kit2 = GraphKit.quick_create([
                [dates[0], dates[-1]].map{|d| d.to_time.to_i - barsize}, 
                [account.average, account.average]
              ])
              kit2.data[0].gp.with = 'l lw 5'
              kit2
            }
            #$debug_gnuplot = true
            #kits.sum.gnuplot
            kit += kits.sum

          else
            kit.data[0].y.data.map!{|expen| expen*-1.0}
          end
          kit.title = "#{account.name_c} Expenditure with average (Total = #{kit.data[0].y.data.sum})"
          CodeRunner::Budget.kit_time_format_x(kit)
          #kit.gnuplot
          #ep ['kit1122', account, kit]
          fork do 
            kit.gnuplot_write("#{account.name_c_file}.eps", size: "4.0in,2.0in")
            exec "epspdf #{account.name_c_file}.eps"
          end
          #%x[ps2eps #{account}.ps]
          #"\\begin{center}\\includegraphics[width=3.0in]{#{account}.eps}\\vspace{1em}\\end{center}"
          #"\\begin{center}\\includegraphics[width=0.9\\textwidth]{#{account}.eps}\\vspace{1em}\\end{center}"
          "\\myfigure{#{account.name_c_file}.pdf}"
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
      _start_dates, dates, expenditures, account_items = account_expenditure(account, account_info)
      #pp account, account_items.map{|items| items.map{|i| i.date.to_s}}
      "\\subsection{#{account}}" + 
        account_items.zip(dates, expenditures).map{|items, date, expenditure|
        if items.size > 0
          "
      \\small
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
      "\\subsection{#{acc.name_c}}
\\tiny
      #{all = acc.runs.find_all{|r|  r.days_ago(@today) < @days_before}
      case acc.type
      when :Expense, :Income
        all = all.sort_by{|r| [r.sub_account, r.date, r.id]}.reverse
      else
        all = all.sort_by{|r| [r.date, r.id]}.reverse
      end
      #ep ['acc', acc, 'ids', all.map{|r| r.id}, 'size', all.size]
all.pieces((all.size.to_f/50.to_f).ceil).map{|piece|
  "\\setlength{\\parindent}{0cm}\n\n\\begin{tabulary}{0.99\\textwidth}{ #{"c " * 3 + " l " + " r " * 3 + "l"}}
  #{piece.map{|r| 
  (CodeRunner::Budget.rcp.component_results - [:sc] + [:sub_account]).map{|res| 
    entry = r.send(res).to_s.latex_escape
    #if 
    entry = entry[0...25] if entry.length > 25
    #if entry.length > 40
    #entry = entry.split(/.{40}/).join(" \\newline ")
    #end
    entry
    #rcp.component_results.map{|res| r.send(res).to_s.gsub(/(.{20})/, '\1\\\\\\\\').latex_escape
  }.join(" & ")
  }.join("\\\\\n")}
\\end{tabulary}"}.join("\n\n")}"
      }.join("\n\n")}
EOF
    end

    def header
      <<EOF
\\documentclass[a5paper]{article}
%\\usepackage[scale=0.9]{geometry}
\\usepackage[left=1cm,top=1cm,right=1cm,nohead,nofoot]{geometry}
%\\usepackage[cm]{fullpage}
\\usepackage{tabulary}
\\usepackage{graphicx}
\\usepackage{multicol}
\\usepackage{hyperref}
\\usepackage{libertine}
\\usepackage{xcolor,listings}
\\newcommand\\Tstrut{\\rule{0pt}{2.8ex}}
\\newcommand\\myfigure[1]{\\vspace*{0em}\\begin{center}

\\includegraphics[width=0.9\\textwidth]{#1}

\\end{center}\\vspace*{0em}

}
\\lstset{%
basicstyle=\\ttfamily\\color{black},
identifierstyle = \\ttfamily\\color{purple},
keywordstyle=\\ttfamily\\color{blue},
stringstyle=\\color{orange}}
\\usepackage[compact]{titlesec}
\\titlespacing{\\section}{0pt}{*0}{*0}
\\titlespacing{\\subsection}{0pt}{*0}{*2}
\\titlespacing{\\subsubsection}{0pt}{*0}{*0}
\\setlength{\\parskip}{0pt}
\\setlength{\\parsep}{0pt}
\\setlength{\\headsep}{0pt}
\\setlength{\\topskip}{0pt}
\\setlength{\\topmargin}{0pt}
\\setlength{\\topsep}{0pt}
\\setlength{\\partopsep}{0pt}
\\begin{document}
\\title{Budget Report from #{@start_date.strftime("%A #{@start_date.day.ordinalize} of %B %Y")} to #{@today.strftime("%A #{@today.day.ordinalize} of %B %Y")}}
\\author{With projections to #{@end_date.strftime("%A #{@end_date.day.ordinalize} of %B %Y")}}
\\date{\\today}
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
#\\subsection{Last Week}
      ##{expense_pie_charts_by_currency('lastweekexpenses', @expense_accounts){|r| 
      ##p ['r.daysago', r.days_ago(@today)]; 
      #r.days_ago(@today) < 7}}
#\\subsection{Last Month}
      ##{expense_pie_charts_by_currency('lastmonthexpenses', @expense_accounts){|r| r.days_ago(@today) < 30}}
#\\subsection{Last Year}
      ##{expense_pie_charts_by_currency('lastyearexpenses', @expense_accounts){|r| r.days_ago(@today) < 365}}

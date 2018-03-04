class Treasurer::Reporter
  class Account
  end
  class SubAccount < Account
    def initialize(name, reporter, runner, runs, external, options={})
      @name = name
      @reporter = reporter
      @runner = runner
      #@projected_accounts_info =Hash[projected_accounts_info.find_all{|k,v| v[:account] == name}]
      @external = external
      @runs = runs.find_all{|r| r.sub_account  == name}
      info[:external] = external if info
      #ep ['sub_accounts333', name, @runs.size, runs.size]
    end
  end
  class Account
    attr_reader :name, :external, :runs, :currency
    attr_accessor :projection, :average
    def initialize(name, reporter, runner, runs, external, options={})
      @name = name
      @reporter = reporter
      @runner = runner
      @currency = options[:currency]
      #@projected_accounts_info =Hash[projected_accounts_info.find_all{|k,v| v[:account] == name}]
      @external = external
      @runs = runs.find_all do |r| 
        #p ['checking11', name, @currency, ACCOUNT_INFO[r.account]] if name == r.external_account and @currency and @external
        #@external ? r.external_account : r.account) == name}
        if not @external
          r.account == name
        elsif info and cur = info[:currencies] and cur.size > 1
          #p ['checking11', name, @currency, ACCOUNT_INFO[r.account]] if name == r.external_account and @currency
          r.external_account == name and acinfo = ACCOUNT_INFO[r.account] and acinfo[:currencies] == [@currency]
        else 
          r.external_account == name
        end
      end
      #p ['Accountinf', name, @currency, @runs.size, runs.size]
      info[:external] = external if info
    end
    def sub_accounts
      @sub_accounts ||= @runs.map{|r| r.sub_account}.uniq.compact.map{|acc| SubAccount.new(acc, @reporter, @runner, @runs, @external, currency: @currency)}
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
      (info && info[:start]) || @runs.map{|r| r.date}.min
    end
    def opening_balance
      (info && info[:opening_balance]) || 0.0
    end
    def has_balance?
      not @runs.find{|r| not r.has_balance?} 
    end
    def balance(date = @reporter.today) 
      date_i = date.to_datetime.to_time.to_i
      #if !date
      #@runs.sort_by{|r| r.date}[-1].balance
      if @external or not has_balance?
        #p ['name is ', name, type]
        #
        balance = (@runs.find_all{|r| r.date <= date and r.date >= opening_date }.map{|r| money_in_sign * (r.deposit - r.withdrawal) * (@external ? -1 : 1)}.sum || 0.0)
        balance += info[:opening_balance] if info[:opening_balance]
        balance
        #Temporary....
        #0.0
      else
        #p ['name33 is ', name, type, @runs.size, @currency]
        nearest_time = @runs.map{|r| (r.date_i - date_i).to_f.abs}.sort[0]
        @runs.find_all{|r| (r.date_i - date_i).to_f.abs == nearest_time}.sort_by{|r| r.id}[-1].balance
      end
    end
    def deposited(today, days_before, &block)
      #p ['name22 is ', name, type, @runs.size]
      #@runs.find_all{|r| r.days_ago(today) < days_before and (!block or yield(r)) }.map{|r| (@external and not ([:Liability, :Income].include?(type))) ? r.withdrawal : r.deposit }.sum || 0
      @runs.find_all{|r| r.days_ago(today) < days_before and (!block or yield(r)) }.map{|r| (@external) ? r.withdrawal : r.deposit }.sum || 0
    end
    def withdrawn(today, days_before)
      #@runs.find_all{|r| r.days_ago(today) < days_before }.map{|r| (@external and not ([:Liability, :Income].include?(type))) ? r.deposit : r.withdrawal }.sum || 0
      @runs.find_all{|r| r.days_ago(today) < days_before }.map{|r| (@external) ? r.deposit : r.withdrawal }.sum || 0
    end
    def currency
      @currency || (info[:currencies] && info[:currencies][0])
    end
    def currency_label
      if @currency
        " (#@currency)"
      else
        ''
      end
    end

    def name_c
      name + currency_label
    end
    def name_c_file
      name_c.to_s.gsub(/[: ()]/, '_')
    end

    def summary_table(today, days_before)

      <<EOF
\\subsubsection{#{name_c}}
\\begin{tabulary}{0.8\\textwidth}{ r | l}
Balance & #{balance} \\\\
Deposited & #{deposited(today, days_before)} \\\\
Withdrawn & #{withdrawn(today, days_before)} \\\\
\\end{tabulary}
EOF
    end
    def summary_line(today, days_before)

      <<EOF
      #{name_c} & #{balance} & #{deposited(today, days_before)} & #{withdrawn(today, days_before)} 
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
      ACCOUNT_INFO[name] ||= {}
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
      Hash[@reporter.projected_accounts_info.find_all{|ext_ac,inf| inf[:linked_account] == name and ext_ac.currency == currency}]
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
      if not (@external or type == :Equity or not has_balance?)
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
      @reporter.projected_account_factor = @reporter.in_limit_discretionary_account_factors[currency]
      limit = futuredates.map{|date| projected_balance(date)}
      kit4 = GraphKit.quick_create([futuredates.map{|d| d.to_time.to_i}, limit])
      @reporter.projected_account_factor = @reporter.stable_discretionary_account_factors[currency]
      #ep ['projected_account_factor!!!!', @reporter.projected_account_factor]
      stable = futuredates.map{|date| projected_balance(date)}
      kit5 = GraphKit.quick_create([futuredates.map{|d| d.to_time.to_i}, stable])
      #exit
      @reporter.projected_account_factor = nil
      kit += (kit2 + kit4 + kit5)
      #kit += (kit2)
      kit = kit3 + kit
      kit.title = "Balance for #{name_c}"
      kit.xlabel = %['Date' offset 0,-2]
      kit.xlabel = nil
      kit.ylabel = "Balance"


      kit.data[0].gp.title = 'Limit'
      kit.data[1].gp.title = 'Previous'
      kit.data[2].gp.title = '0 GBP Discretionary'
      kit.data[2].gp.title = 'Projection'
      kit.data[3].gp.title = 'Limit'
      kit.data[4].gp.title = 'Stable'
      kit.data.each{|dk| dk.gp.with = "l lw 5"}
      kit.gp.key = ' bottom left '
      kit.gp.key = ' rmargin '

      #(p kit; STDIN.gets) if name == :LloydsCreditCard
      CodeRunner::Budget.kit_time_format_x(kit)

      fork do
        (kit).gnuplot_write("#{name_c_file}_balance.eps", size: "4.0in,1.5in") #, latex: true)
        %x[epspdf #{name_c_file}_balance.eps]
      end
      #%x[epspdf #{name}_balance.eps]
    end
    # A string to include the balance graph in the document
    def balance_graph_string
      #accshort = name.gsub(/\s/, '')
      #"\\begin{center}\\includegraphics[width=3.0in]{#{name}_balance.eps}\\end{center}"
      #"\\begin{center}\\includegraphics[width=0.9\\textwidth]{#{name}_balance.eps}\\end{center}"
      "\\myfigure{#{name_c_file}_balance.pdf}"
    end
  end
  class Equity < Account
    def initialize(reporter, runner, accounts, options={})
      @reporter = reporter
      @runner = runner
      @accounts = accounts #.find_all{|acc| not acc.external}
      @currency = options[:currency]
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
    def summary_line(today, days_before)
      "#{name_c} & #{balance(today)} &  & "
    end
  end
end


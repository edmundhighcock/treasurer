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
  class ReportAccount < Account
  end
  class Account
    attr_reader :name, :external, :runs, :currency
    attr_accessor :projection, :average, :original_currency
    def initialize(name, reporter, runner, runs, external, options={})
      @name = name
      @reporter = reporter
      @runner = runner
      @currency = options[:currency]
      #@projected_accounts_info =Hash[projected_accounts_info.find_all{|k,v| v[:account] == name}]
      @external = external
      unless @runs = options[:input_runs] 
        @runs = runs.find_all do |r| 
          #p ['checking11', name, @currency, ACCOUNT_INFO[r.account]] if name == r.external_account and @currency and @external
          #@external ? r.external_account : r.account) == name}
          if not @external
            r.account == name
          elsif @currency and info and cur = info[:currencies] and cur.size > 1
            #p ['checking11', name, @currency, ACCOUNT_INFO[r.account]] if name == r.external_account and @currency
            r.external_account == name and acinfo = ACCOUNT_INFO[r.account] and acinfo[:currencies] == [@currency]
          else 
            r.external_account == name
          end
        end

        if should_report?
          if @external
            @report_runs = runs.find_all do |r|
              r.external_account == name
            end
          else
            @report_runs = @runs
          end
        end
      else
        @report_runs = []
      end
      #p ['Accountinf', name, @currency, @runs.size, runs.size]
      info[:external] = external if info
    end

    # Make the account object that does the reporting. This only
    # gets called if we are doing a currency conversion and
    # this account is in the reeport currency.
    def generate_report_account
      p [name_c, @report_runs.class, @runs.class]
      @report_account = ReportAccount.new(@name, @reporter, @runner, nil, @external, {currency: @currency, input_runs: @report_runs})
      @report_account.instance_variable_set(:@currency, @reporter.report_currency)
      @report_account.instance_variable_set(:@original_currency, currency)
    end

    # The object that actually does the reporting. If there is no
    # currency conversion this is just self.
    # A separate report object is needed as just lumping all the 
    # different currencies together across the board results
    # in double counting.
    #
    # The report account is used for reporting information
    # regarding a particular account. The main accoun is
    # used for calculations e.g. Equity
    def report_account
      @report_account || self
    end

    # Should I report? If there is no currency conversion
    # all accounts report. If there is currency conversion
    # only non-external accounts and accounts in the 
    # right currency report.
    def should_report?
      !@reporter.report_currency or !@external or (@original_currency||currency) == @reporter.report_currency
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
    def red_line(date=@reporter.today)
      if Treasurer::LocalCustomisations.instance_methods.include? :red_line
        val = super(name, date)
        if rc = @reporter.report_currency and rc != @original_currency
          er = EXCHANGE_RATES[[@original_currency,rc]]
          #p ['AAAAAAA', name, @original_currency, er, val, rc]
          val *= er
        end
        val
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
    def available(date = @reporter.today)
      case type
      when :Asset, :Equity
        b = balance
        b - red_line
      when :Liability
        b = balance
        red_line - b
      else
        nil
      end
    end
    def balance(date = @reporter.today, options={}) 
      @balance_cache ||= {}
      if b = @balance_cache[[date,options]] 
        return b 
      end
      date_i = date.to_datetime.to_time.to_i
      #if !date
      #@runs.sort_by{|r| r.date}[-1].balance
      balance = nil
      if @external or not has_balance?
        #p ['name is ', name, type]
        #
        if type == :Expense
          balance = (@runs.find_all{|r| r.date <= date and r.date >= @reporter.start_date }.map{|r| money_in_sign * (r.deposit - r.withdrawal) * (@external ? -1 : 1)}.sum || 0.0)

        else
          balance = (@runs.find_all{|r| r.date <= date and r.date >= opening_date }.map{|r| money_in_sign * (r.deposit - r.withdrawal) * (@external ? -1 : 1)}.sum || 0.0)
          balance += info[:opening_balance] if info[:opening_balance]
          balance
        end
        #Temporary....
        #0.0
      else
        #p ['name33 is ', name, type, @runs.size, @currency]
        nearest_time = @runs.map{|r| (r.date_i - date_i).to_f.abs}.sort[0]
        balance = @runs.find_all{|r| (r.date_i - date_i).to_f.abs == nearest_time}.sort_by{|r| r.id}[-1].balance
      end
      if options[:original_currency] and @original_currency and @original_currency!=currency
        balance = balance*EXCHANGE_RATES[[currency, @original_currency]]
      end
      @balance_cache[[date,options]]=balance
      balance
    end
    def deposited(today, days_before, &block)
      #p ['name223344 is ', name_c, today, days_before]
      #@runs.find_all{|r| r.days_ago(today) < days_before and (!block or yield(r)) }.map{|r| (@external and not ([:Liability, :Income].include?(type))) ? r.withdrawal : r.deposit }.sum || 0
      @runs.find_all{|r| r.days_ago(today) < days_before and r.date <= today and (!block or yield(r)) }.map{|r| (@external) ? r.withdrawal : r.deposit }.sum || 0
    end
    def withdrawn(today, days_before)
      #@runs.find_all{|r| r.days_ago(today) < days_before }.map{|r| (@external and not ([:Liability, :Income].include?(type))) ? r.deposit : r.withdrawal }.sum || 0
      @runs.find_all{|r| r.days_ago(today) < days_before and r.date <= today }.map{|r| (@external) ? r.deposit : r.withdrawal }.sum || 0
    end
    def currency
      @currency || (info[:currencies] && info[:currencies][0])
    end
    def currency_label
      if currency
        " (#{currency}#{@original_currency ? "<-#@original_currency" : ""})"
      else
        ''
      end
    end

    def name_c
      name + currency_label
    end
    def name_c_file
      name_c.to_s.gsub(/[: ()<-]/, '_')
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
      #{name_c} & #{balance.to_tex} & #{deposited(today, days_before).to_tex} & #{withdrawn(today, days_before).to_tex} 
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
      #Hash[@reporter.projected_accounts_info.find_all{|ext_ac,inf| inf[:linked_accounts] == name and ext_ac.currency == currency}]
      Hash[@reporter.projected_accounts_info.find_all{|ext_ac,inf| inf[:linked_accounts][original_currency] and inf[:linked_accounts][original_currency] == name and ext_ac.original_currency == original_currency}]
    end
    def cache
      @cache ||={}
    end
    def non_discretionary_projected_balance(date)
      #ep ['FUTURE_INCOME', FUTURE_INCOME, name] if FUTURE_INCOME.size > 0
      if not (@futures and @regulars)
        @futures = Marshal.load(Marshal.dump(FUTURE_TRANSFERS))
        @regulars = Marshal.load(Marshal.dump(REGULAR_TRANSFERS))
        [@regulars, @futures].each do |transfers|
          @accounts_hash = @reporter.accounts_hash
          transfers.each do |accs, trans|
            next unless accs.include? name
            trans.each do |item, details|
              if  details[:currency] != currency
                #p ['LAGT(O', details[:currency], currency, details, name_c, item]
                details[:size] *= EXCHANGE_RATES[[details[:currency], currency]]
              end
            end
          end
        end
      end
           
          
      cache[[:non_discretionary_projected_balance, date]] ||= 
        balance +
        #@reporter.sum_regular(REGULAR_EXPENDITURE[name], date) + 
        #@reporter.sum_regular(REGULAR_INCOME[name], date) -  
        #@reporter.sum_future(FUTURE_EXPENDITURE[name], date) + 
        #@reporter.sum_future(FUTURE_INCOME[name], date) + 
        (@futures.keys.find_all{|from,to| to == name}.map{|key|
          @reporter.sum_future(@futures[key], date) * money_in_sign
        }.sum||0) - 
        (@futures.keys.find_all{|from,to| from == name}.map{|key|
          @reporter.sum_future( @futures[key], date) * money_in_sign
        }.sum||0) +
        (@regulars.keys.find_all{|from,to| to == name}.map{|key|
          @reporter.sum_regular(@regulars[key], date) * money_in_sign
        }.sum||0) - 
        (@regulars.keys.find_all{|from,to| from == name}.map{|key|
          @reporter.sum_regular( @regulars[key], date) * money_in_sign
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

      [kit2,kit4,kit5].each{|k| k.data[0].y.data[0] = balance(today)}
      #exit
      @reporter.projected_account_factor = nil
      kit += ( kit4 + kit5 + kit2)
      #kit.yrange = [(m = kit.data.map{|dk| dk.y.data.min}.min; m-m.abs*0.1), (m=kit.data.map{|dk| dk.y.data.max}.max; m+m.abs*0.1)]
      #kit += (kit2)
      kit = kit3 + kit
      kit.title = "Balance for #{name_c}"
      kit.xlabel = %['Date' offset 0,-2]
      kit.xlabel = nil
      kit.ylabel = "Balance"
      kit.gp.mytics= "5"
      kit.gp.grid = "ytics mytics lw 2,lw 1"


      kit.data[0].gp.title = 'Limit'
      kit.data[1].gp.title = 'Previous'
      #kit.data[2].gp.title = '0 GBP Discretionary'
      kit.data[2].gp.title = 'Avoid Limit'
      kit.data[3].gp.title = 'Stable'
      kit.data[4].gp.title = 'Projection'
      kit.data.each{|dk| dk.gp.with = "l lw 5"}
      kit.data[4].gp.with = "l lw 5 dt 2 lc rgb 'black' "
      kit.gp.key = ' bottom left '
      kit.gp.key = ' rmargin samplen 2'
      kit.gp.decimalsign = 'locale "en_GB.UTF-8"'

      #bal, avail = balance, available     
        
      if avail = available
        kit.gp.label = [
          %[ "Balance \\n#{balance}\\n\\nAvailable\\n#{avail}" at screen 0.95, screen 0.5 right],
        ]
      end

      #(p kit; STDIN.gets) if name == :LloydsCreditCard
      CodeRunner::Budget.kit_time_format_x(kit)
      kit.gp.format.push %[y "%'.2f"]
      size = case type
             when :Equity
               "4.0in,4.0in"
             else
               "4.0in,2.5in"
             end

      fork do
        (kit).gnuplot_write("#{name_c_file}_balance2.eps", size: size) #, latex: true)
        system %[ps2epsi #{name_c_file}_balance2.eps #{name_c_file}_balance.eps]
        system %[epstopdf #{name_c_file}_balance.eps]
      end
      #%x[epstopdf #{name}_balance.eps]
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
    def should_report?
      true
    end
    def type
      :Equity
    end
    def name
      :Equity
    end
    def red_line(date=@reporter.today)
      @accounts.map{|acc|
        case acc.type
        when :Asset
          acc.red_line(date)
        when :Liability
          -acc.red_line(date)
        else
          0.0
        end
      }.sum + sum_of_assets
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
      }.sum + sum_of_assets
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
      }.sum + sum_of_assets
    end
    def sum_of_assets
      ASSETS.find_all{|name,details| details[:currency] == currency}.map{|name,details| details[:size]}.sum or 0.0
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
      "#{name_c} & #{balance(today).to_tex} &  & "
    end
  end
end


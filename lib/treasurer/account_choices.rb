
require 'sqlite3'
class CodeRunner::Budget
  # Initialize the sqlite database that stores the user
  # choices for external_account and sub_account  
  def self.init_sqlite(folder)
    require 'sqlite3'
    FileUtils.makedirs(folder + '/sqlite')
    Dir.chdir(folder + '/sqlite') do 
      db = sqlitedb(Dir.pwd) 
      _rows = db.execute <<-SQL
        create table external_accounts (
          eid INTEGER primary key,
          external_account text
        );
      SQL
      _rows = db.execute <<-SQL
        create table sub_accounts (
          sid INTEGER primary key,
          sub_account text,
          eid INTEGER,
          foreign key (eid) references external_accounts (eid)
        );
      SQL
      _rows = db.execute <<-SQL
        create table choices (
          id INTEGER primary key,
          signature text,
          sid INTEGER,
          foreign key (sid) references sub_accounts (sid)
        );
      SQL

    end
  end

  DATABASES={}

  def self.sqlitedb(folder)
    DATABASES[folder] ||= SQLite3::Database.new folder + "/treasurer.db"
  end

  def sqlitedb
    self.class.sqlitedb(@runner.root_folder + '/sqlite')
  end

  # Get stored choices from the old flat files
  def get_old_choices
    chosen = false
    Hash.phoenix(@runner.root_folder + '/account_choices.rb') do |choices_hash|
      if choices_hash[signature]
        chosen = choices_hash[signature]
      elsif choices_hash[data_line] 
        #choices_hash[data_line][:external_account] = 
        #choices_hash[data_line][:external_account].to_sym #fixes earlier bug
        #choices_hash[data_line][:sub_account] = 
        #choices_hash[data_line][:sub_account].to_sym #fixes earlier bug
        chosen = choices_hash[data_line]
        choices_hash[signature] = choices_hash[data_line]
        choices_hash.delete(data_line)
      elsif choices_hash[old_data_line]
        chosen = choices_hash[old_data_line]
        choices_hash[signature] = choices_hash[old_data_line]
      end
    end
    if chosen
      puts "ADDING TO DB"
      add_sqlite_choices(chosen)
    end
    chosen||{}
  end

  def sqlite_eid(account_spec)
    eid = nil
    until eid
      rows = sqlitedb.execute(
        'SELECT (eid) ' +
        'FROM external_accounts ' +
        'WHERE external_account = ? ', 
        account_spec[:external_account].inspect
      )
      pp 'ROWSSS', rows
      if rows.size < 1
        sqlitedb.execute(
          'INSERT INTO external_accounts  ' + 
          '(external_account) VALUES (?)', 
          account_spec[:external_account].inspect
        )
      elsif rows.size > 1
        raise "Duplicate external_accounts"
      else
        eid=rows[0][0]
        raise TypeError.new("Bad eid: #{eid.inspect}") unless eid.kind_of? Integer 
      end
    end
    eid
  end

  def sqlite_sid(account_spec)
    eid = sqlite_eid(account_spec)
    sid = nil
    until sid
      rows = sqlitedb.execute(
        'SELECT (sid) ' +
        'FROM sub_accounts ' +
        'WHERE sub_account = ? AND eid= ?', 
        [account_spec[:sub_account].inspect, eid]
      )
      pp 'ROWSSS', rows
      if rows.size < 1
        sqlitedb.execute(
          'INSERT INTO sub_accounts  ' + 
          '(sub_account, eid) VALUES (?, ?)', 
          [account_spec[:sub_account].inspect, eid]
        )
      elsif rows.size > 1
        raise "Duplicate sub_accounts"
      else
        sid=rows[0][0]
        raise TypeError.new("Bad sid: #{sid.inspect}") unless sid.kind_of? Integer 
      end
    end
    sid
  end

  def add_sqlite_choices(chosen)
    sid = sqlite_sid(chosen)
    sqlitedb.execute(
      'INSERT INTO choices' + 
      '(signature, sid) VALUES (?, ?)', 
      [signature.inspect, sid]
    )
  end

  # Get stored choices from the sqlite database
  def get_sqlite_choices
    rows = sqlitedb.execute(
      'SELECT external_account, sub_account ' +
      'FROM choices ' +
      'LEFT JOIN sub_accounts  ON ' +
      'sub_accounts.sid = choices.sid '  +
      'LEFT JOIN external_accounts  ON ' +
      'external_accounts.eid = sub_accounts.eid ' +
      'WHERE signature = ?', 
      signature.inspect
    )
    #pp "RRRRROOO", rows
    if rows.size == 1
      return {
        external_account: eval(rows[0][0]),
        sub_account: eval(rows[0][1]),
      }
    elsif rows.size > 1
      raise "Duplicate signatures in sqlitedb"
    else
      return {}
    end
  end

  # Get new choices from the user interactively.  
  def get_new_choices
    ext_account = nil
    chosen = false
    transactions = runner.component_run_list.values.sort_by{|r| r.date}
    idx = transactions.index(self)
    ff = Proc.new{|float| float ? sprintf("%8.2f", float) : " "*8}
    format = Proc.new{|runs| runs.map{|r| 
      #begin
        sprintf("%70s %s %8s %8s %8s %-12s", r.description[0,70], r.date.to_s, ff.call(r.deposit), ff.call(r.withdrawal), ff.call(r.balance), r.account)
      #rescue
        #p r
        #p r.data_line
        #exit
      #end
    }.join("\n")}
    format_choices = Proc.new{|chs| chs.map{|k,v| Terminal::LIGHT_GREEN + k + ":" + Terminal.default_colour + v}.join(" ")}
    Dir.chdir(@runner.root_folder) do
      sym = nil
      print_transactions = Proc.new do
            puts format.call(transactions.slice([idx-30, 0].max, 30))
            puts Terminal::LIGHT_GREEN + format.call([transactions[idx]]) + "<-----" + Terminal.default_colour
            sz = transactions.size
            puts format.call(transactions.slice([idx+1, sz-1].min, 10))
      end
      while not chosen
        Hash.phoenix('external_accounts.rb') do |account_hash|
          #account_hash.each{|k,v| v[:name] = v[:name].to_sym} #Fixes an earlier bug
          #choices = account_arr.size.times.map{|i| [i,account_arr[i][:name]]}
          choices = account_hash.map{|k,v| [v[:sym], k]}.to_h
          choices["-"] = "Transfer"
          puts Terminal.default_colour
          print_transactions.call
          #format = Proc.new{|runs| runs.map{|r| r.signature.map{|d| d.to_s}.join(",")}.join("\n")}
          puts
          puts format_choices.call(choices)
          puts
          puts "Please choose from the above external accounts for this transaction." +
            "If you wish to add a new account type 0. To quit type q. " +
                "To start again for this transaction, type z. To mark it as transfer between" +
                "two non-external accounts, press -."
          while not chosen
            require 'io/console'
            choice = STDIN.getch
            if choice == "q"
              throw :quit_data_entry
            elsif choice == "0"
              puts "Please type the name of the new account"
              name = STDIN.gets.chomp.to_sym
              puts "Please enter a symbol to represent this account (e.g. digit, letter, punctuation)."
              sym = false
              until sym
                sym = STDIN.getch
                if choices.keys.include? sym
                  puts "This symbol is taken"
                  sym = false
                end
              end
              account_hash[name] = {name: name, sym: sym, sub_accounts: {}}
              #choices_hash[@id] = name
              chosen = name
            elsif choice == "z"
              chosen = false
              break
            elsif choice == "-"
              ext_account = "Transfer"
              chosen = "Transfer"
              break
            elsif not choices.keys.include? choice
              puts "Error: this symbol does not correspond to an account"
            else
              chosen = choices[choice] #account_hash[choice][:name]
            end
          end
          #Hash.phoenix('account_choices.rb') do |choices_hash|
          #choices_hash[data_line] = {external_account: chosen}
          #end
        end
        next if not chosen
        if ext_account and chosen
            break
        end
        ext_account = chosen
        chosen = false
        Hash.phoenix('external_accounts.rb') do |account_hash|
          #choices = account_arr.size.times.map{|i| [i,account_arr[i][:name]]}
          sub_accounts = account_hash[ext_account][:sub_accounts]
          sub_accounts.each{|k,v| v[:name] = v[:name].to_sym} #Fixes an earlier bug
          choices = sub_accounts.map{|k,v| [v[:sym], k]}.to_h
          #puts "-" * data_line.size
          print_transactions.call
          puts
          puts format_choices.call(choices)
          puts
          puts "Please choose from the above sub-accounts for this transaction. " + 
            "If you wish to add a new sub account, type 0. To quit, type q. " +
            "To start again for this transaction, type z"
          while not chosen
            require 'io/console'
            choice = STDIN.getch
            if choice == "q"
              throw :quit_data_entry
            elsif choice == "0"
              puts "Please type the name of the new sub account"
              name = STDIN.gets.chomp.to_sym
              puts "Please enter a symbol to represent this account (e.g. digit, letter, punctuation)."
              sym = false
              until sym
                sym = STDIN.getch
                if choices.keys.include? sym
                  puts "This symbol is taken"
                  sym = false
                end
              end
              sub_accounts[name] = {name: name, sym: sym}
              #choices_hash[@id] = name
              chosen = name
            elsif choice == "z"
              chosen = false
              ext_account = nil
              break
            elsif not choices.keys.include? choice
              puts "Error: this symbol does not correspond to a sub-account"
            else
              chosen = choices[choice] #sub_accounts[choice][:name]
            end
          end
        end
        next if not chosen
        #Hash.phoenix('account_choices.rb') do |choices_hash|
          #choices_hash[signature] = {external_account: ext_account, sub_account: chosen}
        #end
      end #while not chosen
      add_sqlite_choices({external_account: ext_account, sub_account: chosen})
    end
    {external_account: ext_account, sub_account: chosen}
  end


  # All transactions occur between two accounts. 
  # One of those accounts is always physical (e.g. bank account, loan, credit card)
  # and the other can be either physical or a virtual account of the users choice,
  # e.g. Food or Petrol or Energy, or maybe WeeklyBudget and LongTermBudget etc.
  def external_account
    unless @runner
      raise "No runner for " + data_line
    end
    if not @external_account
      @external_account = (
        (ch = get_sqlite_choices)[:external_account] or
        (ch = get_old_choices)[:external_account] or
        (ch = get_new_choices)[:external_account]
      )
      @sub_account = ch[:sub_account]
      #if not @external_account
        #raise "No external account for #{data_line}"
      #end
    end
    return @external_account
  end
  
  # All transactions have a subaccount. For transactions between
  # physical accounts this will almost always be just 'Transfer'
  # or similar, but virtual accounts will have more meaningful
  # sub_accounts, e.g. Food might have Groceries, EatingOut
  # or WeeklyBudget might have Transport, Food, Clothes... depending
  # on the users preferred way of organising things.
  # The sub_accounts are primarily a labelling exercise, but done 
  # well can be very helpful in showing a breakdown of expenditure.
  def sub_account
    return @sub_account if @sub_account
    puts "SIGNATURE ", signature.inspect
    Dir.chdir(@runner.root_folder) do
      external_account until (
        choices = nil
        Hash.phoenix('account_choices.rb'){|choices_hash| choices = choices_hash[signature]}
        #p [choices, data_line]
        choices
      ) and choices[:sub_account]
      @sub_account = choices[:sub_account]
    end
  end
end


# A tool for analysing finances and making budget projections

require 'getoptlong'

module CommandLineFlunky
	
	STARTUP_MESSAGE = "\n------Treasurer Financial Utility (c) Edmund Highcock------"

	MANUAL_HEADER = <<EOF
			
-------------Treasurer Financial Utility Manual---------------

  Written by Edmund Highcock (2014)

NAME

  treasurer


SYNOPSIS
	
  treasurer <command> [arguments] [options]


DESCRIPTION

  Generate a financial report from one or more bank accounts, credit cards
  etc by analysing internet banking sheets. Simple local files can be used to
  customise the reports by adding budgets and categories
  
EXAMPLES

  treasurer init my_accounts_folder

  treasurer add my_bank_statement.csv

  treasurer report 

  treasurer add_folder folder_of_bank_statements
   
   
EOF
	
	COMMANDS_WITH_HELP = [
		['add_file', 'add', 2,  'Import a new internet banking spreadsheet for the given account.', ['csv spreadsheet filename', 'account name'], []],
		['add_folder_of_files', 'addf', 1,  'Import all internet banking spreadsheets within the given folder .', ['folder'], []],
		['init_root_folder', 'init', 1,  'Create a new folder and initialise it for storing treasurer data.', ['folder'], []],
		['create_report', 'report', 0,  'Generate a detailed report (typeset using latex) showing account activity, spending by category, and projections.', [], [:a, :b, :t]],
    ['status', 'st', 0,  'Print the transactions to screen..', [], [:C]],

	]
	


	COMMAND_LINE_FLAGS_WITH_HELP = [
		['--after', '-a', GetoptLong::REQUIRED_ARGUMENT, 'Calculate projections up till given number of days after today'],		
		['--before', '-b', GetoptLong::REQUIRED_ARGUMENT, 'Start budget from given number of days before today'],		
		['--today', '-t', GetoptLong::REQUIRED_ARGUMENT, "Specify today's date, i.e. change the date on which the report is generated."],		
		['--coderunner', '-C', GetoptLong::REQUIRED_ARGUMENT, "Options to pass to CodeRunner, the engine which manages the transaction data."],		
		['--month', '-m', GetoptLong::REQUIRED_ARGUMENT, "Overrides -a, -b and -t and produces a report for a given month"],		
		#['--formats', '-f', GetoptLong::REQUIRED_ARGUMENT, "A list of formats pertaining to the various input and output files (in the order which they appear), separated by commas. If they are all the same, only one value may be given. If a value is left empty (i.e. there are two commas in a row) then the previous value will be used. Currently supported formats are #{SUPPORTED_FORMATS.inspect}. "],		

		]

	LONG_COMMAND_LINE_OPTIONS = [
	#["--no-short-form", "", GetoptLong::NO_ARGUMENT, %[This boolean option has no short form]],
	] 
		
	# specifying flag sets a bool to be true

	CLF_BOOLS = []

	CLF_INVERSE_BOOLS = [] # specifying flag sets a bool to be false
	
	PROJECT_NAME = 'treasurer'
		
	def self.method_missing(method, *args)
# 		p method, args
		Treasurer.send(method, *args)
	end
	
	#def self.setup(copts)
		#CommandLineFlunkyTestUtility.setup(copts)
	#end
	
	SCRIPT_FILE = __FILE__
end

class Treasurer
	class << self
		# This function gets called before every command
		# and allows arbitrary manipulation of the command
		# options (copts) hash
		def setup(copts)
			# None neededed
			copts[:b] = copts[:b].to_i
			copts[:a] = copts[:a].to_i
			copts[:t] = Date.parse(copts[:t]) if copts[:t]
	  end
		def verbosity
			2
		end
	end
	SCRIPT_FOLDER = folder = File.dirname(File.expand_path(__FILE__))
end

$has_put_startup_message_for_code_runner = true
require 'date'
require 'coderunner'
require 'treasurer/commands.rb'
require 'treasurer/report.rb'
require 'treasurer/analysis.rb'
require 'treasurer/accounts.rb'


######################################
# This must be at the end of the file
#
require 'command-line-flunky'
###############################

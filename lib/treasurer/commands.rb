
class Treasurer
class << self
	def add_file(file, account, copts={})
		check_is_treasurer_folder
		ep 'entries', Dir.entries
		CodeRunner.submit(p: "{data_file: '#{File.expand_path(file)}', account: '#{account}'}")
	end
	def check_is_treasurer_folder
		raise "This folder has not been set up to use with Treasurer; please initialise a folder with treasurer init" unless FileTest.exist? '.code_runner_script_defaults.rb' and eval(File.read('.code_runner_script_defaults.rb'))[:code] == 'budget'
	end
	def init_root_folder(folder, copts={})
		raise "Folder already exists" if FileTest.exist? folder
		FileUtils.makedirs(folder)
		FileUtils.cp(SCRIPT_FOLDER + '/treasurer/local_customisations.rb', folder + '/local_customisations.rb')
		CodeRunner.fetch_runner(Y: folder, C: 'budget', X: '/dev/null')
		eputs "\n\n Your treasurer folder '#{folder}' has been set up. All further treasurer commands should be run from within this folder.\n"
	end

	def method_missing(meth, *args)
		CodeRunner.send(meth, *args)
	end
end
end


class Treasurer
class << self
	def init(folder, copts={})
		raise "Folder already exists" if FileTest.exist? folder
		FileUtils.makedirs(folder)
		FileUtils.cp(SCRIPT_FOLDER + '/treasurer/local_customisations.rb', folder + '/local_customisations.rb')
		CodeRunner.fetch_runner(Y: folder, C: 'budget', X: '/dev/null')
	end
end
end

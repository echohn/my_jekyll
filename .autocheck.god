God.watch do |w|
	w.name = 'check_and_build'
	w.start = 'rake check_and_build > /tmp/check_and_build.log 2>&1'
	w.dir = File.expand_path('..',__FILE__)
	w.start_if do |start|
		start.condition(:process_running) do |c|
			c.interval = 5.minutes
			c.running = false
		end
	end
end

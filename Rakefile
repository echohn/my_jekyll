require 'time'

desc "Build my site ..."
task :build do
  system "jekyll build"
end

desc "Start a locally server"
task :s do
  system "jekyll server -s . -d _site -P 3000 -w"
end

# Usage: rake post title="A Title" [date="2014-04-14"]
desc "Create a new post"
task :new do
  unless FileTest.directory?('./_posts')
    abort("rake aborted: '_posts' directory not found.")
  end

  title = ENV["title"] || "new-post"
  slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  begin
    date = (ENV['date'] ? Time.parse(ENV['date']) : Time.now)
           .strftime('%Y-%m-%d')
  rescue Exception => e
    puts "Error: date format must be YYYY-MM-DD!"
    exit -1
  end

  filename = File.join('.', '_posts', "#{date}-#{slug}.md")
  if File.exist?(filename)
    abort("rake aborted: #{filename} already exists.")
  end

  puts "Creating new post: #{filename}"
  open(filename, 'w') do |post|
    post.puts "---"
    post.puts "layout: post"
    post.puts "title: \"#{title.gsub(/-/,' ')}\""
    post.puts "date: #{date}"
    post.puts "categories:"
    post.puts "tags: "
    post.puts "---"
  end

  exec "open #{filename}"
end

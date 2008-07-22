require "find"
require "yaml"
require "optparse"

OPTIONS = {
  :project => "Chyrp v2.0 Beta 5",
  :maintainer => "Alex Suraci <suracil.icio.us@gmail.com>",
  :domain  => nil,
  :msgstr  => "",#"XXX",
  :msgstr_filter => "",#"XXX :: %s",
  :exclude => [".git", "modules", "lib", "feathers", "themes", "config.yaml.php", "database.yaml.php"],
  :keys    => ["name", "description", "plural", "notifications", "confirm"]
}

ARGV.options do |o|
  script_name = File.basename($0)

  o.banner =    "Usage: #{script_name} [directory] [OPTIONS]"
  o.define_head "Scans [directory] recursively for various forms of Gettext translations and outputs to a .po file."

  o.separator ""

  o.on("--project=[val]", String,
       "The name of the project the .pot file is for.") { |OPTIONS[:project]| }
  o.on("--maintainer=[val]", String,
       "The maintainer of the .pot file. (Firstname Lastname <foo@bar.com>)") { |OPTIONS[:maintainer]| }
  o.on("--domain=[val]", String,
       "Domain to scan for translations.") { |OPTIONS[:domain]| }
  o.on("--msgstr=[val]", String,
       "Message string to translate all found translations to. Useful for debugging.") { |OPTIONS[:mststr]| }
  o.on("--exclude=[val1,val2]", Array,
       "A list of directories to exclude from the scan.") { |OPTIONS[:exclude]| }
  o.on("--keys=[val1,val2]", Array,
       "A list of YAML keys for which to generate translations.") { |OPTIONS[:keys]| }

  o.separator ""

  o.on_tail("-h", "--help", "Show this help message.") do
    puts o
    exit
  end

  o.parse!
end

class Gettext
  def initialize(start)
    @start, @files, @translations = start, [], {}

    @domain = OPTIONS[:domain].nil? ? "" : ', "'+OPTIONS[:domain]+'"'
    @twig_domain = (OPTIONS[:domain].nil? or OPTIONS[:domain] == "theme") ? "" : '\("'+OPTIONS[:domain]+'"\)'

    prepare_files
    do_scan
    print_pofile
  end

  def prepare_files
    Find.find(@start) do |path|
      cleaned = path.sub("./", "")
      if FileTest.directory?(path)
        if OPTIONS[:exclude].include?(cleaned)
          Find.prune
        else
          next
        end
      else
        next unless path =~ /\.(php|twig|yaml)/
        @files << [cleaned, path] if File.read(path) =~ /(__|_f|_p)\(("|').*?\2#{@domain}\)/
        @files << [cleaned, path] if File.read(path) =~ /("|').*?\1 ?\| ?translate#{@twig_domain}/
        @files << [cleaned, path] if File.read(path) =~ /("|').*?\1 ?\| ?translate_plural\(("|').*?\2, ?.*?#{@domain}\) ?\| ?format\(.*?\)/
        @files << [cleaned, path] if path =~ /\.yaml/
      end
    end
  end

  def do_scan
    @files.each do |cleaned, file|
      if File.basename(file) =~ /\.yaml$/
        scan_yaml file, cleaned
        next
      end

      counter = 1
      File.open(file, "r") do |infile|
        while line = infile.gets
          line.gsub!("\\\"", "{QUOTE}") # So that [^"]+ doesn't match \"'s in the translation.
          scan_normal      line, counter, file, cleaned
          scan_filter      line, counter, file, cleaned
          scan_plural      line, counter, file, cleaned
          scan_twig        line, counter, file, cleaned
          scan_twig_filter line, counter, file, cleaned
          scan_twig_plural line, counter, file, cleaned
          counter += 1
        end
      end
    end
  end

  def scan_normal(text, line, filename, clean_filename)
    text.gsub(/__\(("|')([^"]+)\1#{@domain}\)/) do
      if @translations[$2].nil?
        @translations[$2] = { :places => [clean_filename + ":" + line.to_s],
                              :filter => false,
                              :plural => false }
      elsif not @translations[$2][:places].include?(clean_filename + ":" + line.to_s)
        @translations[$2][:places] << clean_filename + ":" + line.to_s
      end
    end
  end

  def scan_filter(text, line, filename, clean_filename)
    text.gsub(/_f\(("|')([^"]+)\1, .*?#{@domain}\)/) do
      if @translations[$2].nil?
        @translations[$2] = { :places => [clean_filename + ":" + line.to_s],
                              :filter => true,
                              :plural => false }
      elsif not @translations[$2][:places].include?(clean_filename + ":" + line.to_s)
        @translations[$2][:places] << clean_filename + ":" + line.to_s
      end
    end
  end

  def scan_plural(text, line, filename, clean_filename)
    text.gsub(/_p\(("|')([^"]+)\1, ("|')([^"]+)\3, .*?#{@domain}\)/) do
      if @translations[$2].nil?
        @translations[$2] = { :places => [clean_filename + ":" + line.to_s],
                              :filter => true,
                              :plural => $4 }
      elsif not @translations[$2][:places].include?(clean_filename + ":" + line.to_s)
        @translations[$2][:places] << clean_filename + ":" + line.to_s
      end
    end
  end

  def scan_twig(text, line, filename, clean_filename)
    text.gsub(/("|')([^"]+)\1 ?\| ?translate(?!_plural)#{@twig_domain}(?! ?\| ?format)/) do
      if @translations[$2].nil?
        @translations[$2] = { :places => [clean_filename + ":" + line.to_s],
                              :filter => false,
                              :plural => false }
      elsif not @translations[$2][:places].include?(clean_filename + ":" + line.to_s)
        @translations[$2][:places] << clean_filename + ":" + line.to_s
      end
    end
  end

  def scan_twig_filter(text, line, filename, clean_filename)
    text.gsub(/("|')([^"]+)\1 ?\| ?translate(?!_plural)#{@twig_domain} ?\| ?format\(.*?\).*?/) do
      if @translations[$2].nil?
        @translations[$2] = { :places => [clean_filename + ":" + line.to_s],
                              :filter => true,
                              :plural => false }
      elsif not @translations[$2][:places].include?(clean_filename + ":" + line.to_s)
        @translations[$2][:places] << clean_filename + ":" + line.to_s
      end
    end
  end

  def scan_twig_plural(text, line, filename, clean_filename)
    text.gsub(/("|')([^"]+)\1 ?\| ?translate_plural\(("|')([^"]+)\3, .*?#{@domain}\) ?\| ?format\(.*?\)/) do
      if @translations[$2].nil?
        @translations[$2] = { :places => [clean_filename + ":" + line.to_s],
                              :filter => true,
                              :plural => $4 }
      elsif not @translations[$2][:places].include?(clean_filename + ":" + line.to_s)
        @translations[$2][:places] << clean_filename + ":" + line.to_s
      end
    end
  end

  def scan_yaml(filename, clean_filename)
    info = YAML.load_file(filename)
    counter = 0
    info.each do |key, val|
      counter += 1
      next unless OPTIONS[:keys].include?(key)

      if val.class == String
        val.gsub!("\"", "{QUOTE}")
        if @translations[val].nil?
          @translations[val] = { :places => [clean_filename + ":" + counter.to_s],
                                 :filter => false,
                                 :plural => false }
        elsif not @translations[val][:places].include?(clean_filename + ":" + counter.to_s)
          @translations[val][:places] << clean_filename + ":" + counter.to_s
        end
      end
      if val.class == Array
        val.each do |val|
          val.gsub!("\"", "{QUOTE}")
          if @translations[val].nil?
            @translations[val] = { :places => [clean_filename + ":" + counter.to_s],
                                   :filter => false,
                                   :plural => false }
          elsif not @translations[val][:places].include?(clean_filename + ":" + counter.to_s)
            @translations[val][:places] << clean_filename + ":" + counter.to_s
          end
          counter += 1
        end
      end
    end
  end

  def print_pofile
    puts '# '+OPTIONS[:project]+' Translation File.'
    puts '# Copyright (C) YEAR '+OPTIONS[:maintainer].gsub(/ <([^>]+)>/, "")
    puts '# This file is distributed under the same license as the '+OPTIONS[:project]+' package.'
    puts '# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.'
    puts '#'
    puts '#, fuzzy'
    puts 'msgid ""'
    puts 'msgstr ""'
    puts '"Project-Id-Version: '+OPTIONS[:project]+'\n"'
    puts '"Report-Msgid-Bugs-To: '+OPTIONS[:maintainer].gsub(/[^<]+ <([^>]+)>/, "\\1")+'\n"'
    puts '"POT-Creation-Date: '+Time.now.utc.strftime("%Y-%m-%d %H:%M")+'+0000\n"'
    puts '"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"'
    puts '"Last-Translator: FIRST LAST <EMAIL@EXAMPLE.COM>\n"'
    puts '"Language-Team: LANGUAGE <EMAIL@EXAMPLE.COM>\n"'
    puts '"MIME-Version: 1.0\n"'
    puts '"Content-Type: text/plain; charset=CHARSET\n"'
    puts '"Content-Transfer-Encoding: 8bit\n"'
    puts '"Plural-Forms: nplurals=INTEGER; plural=EXPRESSION;\n"'
    puts ''

    output = ""
    @translations.each do |text, attr|
      attr[:places].each do |place|
        output << "#: "+place+"\n"
      end
      output << "#, php-format\n" if attr[:filter]
      output << "msgid \""+text+"\"\n"
      output << "msgid_plural \""+attr[:plural]+"\"\n" if attr[:plural]

      if attr[:plural]
        output << "msgstr[0] \"#{OPTIONS[:msgstr]}\"\n"
        output << "msgstr[1] \"#{OPTIONS[:msgstr]}\"\n"
      else
        output << "msgstr \"#{(attr[:filter]) ? OPTIONS[:msgstr_filter] || OPTIONS[:msgstr] : OPTIONS[:msgstr]}\"\n"
      end

      output << "\n"
    end
    puts output.gsub("{QUOTE}", "\\\"")
  end
end

Gettext.new ARGV[0] || "."
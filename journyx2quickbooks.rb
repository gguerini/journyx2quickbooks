require 'yaml'
require 'awesome_print'
require 'date'

class JournyX2QuickBooks

  NOT_FOUND = "not found!"

  def initialize

    @missing_files_list = []
    @files_verified = true

    read_settings()

    # Verify if the necessary files exist
    verify_basic_files()

    # Verify if the report file exists
    @report_file = get_newest_report_file()
    file_exists?(@report_file.empty? ? "JournyX Report File" : @report_file)

    if @files_verified
      @companies = load_customers_projects_list
      @template_file = File.read(@template_file_path)
    end

  end

  def run

    if !@files_verified

      puts "****** SCRIPT ABORTED *******"
      puts "Missing #{@missing_files_list.count > 1 ? "files" : "file"}:"
      @missing_files_list.each { |file| puts " - #{file}" }

    else

      process_report()

      # Apply processed content to the template
      @template_file.gsub!("#PROJECT_LIST#", @project_list)
      @template_file.gsub!("#TASK_LIST#", @task_list)

      currente_date = DateTime.now.strftime('%Y%m%d')

      # Export the files
      save_file("quickbooks_#{currente_date}.txt", @template_file)
      save_file("quickbooks_projects_not_found_#{currente_date}.txt", @not_found_project_list)

      puts "****** SCRIPT COMPLETE *******"

    end

  end

  private

	  def read_settings
	    settings 								= YAML.load_file("settings.yml")
	    @journyx_reports_path 	= settings["journyx_reports_path"]
	    @export_path 						= settings["export_path"]
	    @template_file_path			= settings["template_file_path"]
	    @data_file_path					= settings["data_file_path"]
	  end

	  def get_newest_report_file
	    Dir[@journyx_reports_path].sort_by{ |file| File.mtime(file) }.last(1).join
	  end

	  def verify_basic_files
	    file_exists?(@template_file_path)
	    file_exists?(@data_file_path)
	  end

	  def load_customers_projects_list
	    customers_projects_list = Hash.new { |hash, key| hash[key] = [] }

	    File.open(@data_file_path).each do |line|
	      if line.slice(0, 4) == 'CUST' and line.include? ':'
	        strline = line.gsub('"', '').split(":")
	        company_name = strline[0].gsub('CUST', '').strip
	        project_name = strline[1].match(/(PJ+\w+)/).to_s

	        unless project_name.nil? or project_name.empty?
	          customers_projects_list[company_name] << project_name
	        end
	      end
	    end

	    customers_projects_list
	  end

	  def get_company_name(project_name)
	  	company_name = NOT_FOUND
	  	
	    @companies.each do |key, value|
	      if value.include?(project_name)
	        company_name = key
	        break
	      end
	    end

	    company_name
	  end

	  def generate_projects_list(project_list)
	    company_project_list = []

	    project_list.each do |proj|
	      company_name = get_company_name(proj)
	      company_project_name = "#{company_name}:#{proj}"

	      unless company_name == NOT_FOUND
	        company_project_list << company_name if !company_project_list.include?(company_name)
	        company_project_list << company_project_name if !company_project_list.include?(company_project_name)
	      end

	    end

	    project_list_export = ""
	    company_project_list.map { |e| project_list_export += "CUST	#{e}\n" }
	    project_list_export.chomp!

	  end

	  def split_list_into_lines(list)
	    list_in_lines = ""
	    list.map { |line| list_in_lines += line }
	    list_in_lines
	  end

	  def process_report

	    project_name 						= ""
	    task_name 							= ""
	    project_list 						= []
	    task_list 							= []
	    not_found_project_list 	= []
	    currente_date 					= DateTime.now.strftime('%m/%d/%Y')

	    File.open(@report_file).each { |line|

	      strline = line.split("	")

	      item_name 		= strline[0].strip
	      hours 				= strline[1].to_f
	      description 	= strline[2].to_s.chomp

	      if item_name.slice(0, 6) == "....PJ" && hours > 0

	        project_name = item_name.gsub(".", "")
	        project_list << project_name if !project_name.empty?

	      elsif item_name.slice(0, 6) == "......" && hours > 0

	        task_name = description.empty? ? item_name.gsub(".", "") : description
	        task_name.gsub!(/([0-9]+[\s])/,'')

	      elsif item_name.include? "subtotal for" and !project_name.empty? and !task_name.empty?

	        employee_name = item_name.gsub("subtotal for", "").strip
	        company_name = get_company_name(project_name)

	        if company_name != NOT_FOUND
	          task_list << "TIMEACT	#{currente_date}	#{company_name}:#{project_name}	JournyX	Engineering Service (by CPS)		#{hours}		#{task_name} - #{employee_name}	N	1\n"
	        else
	          not_found_project_list << "#{project_name} - #{company_name} - #{hours} - #{task_name} - #{employee_name}\n"
	        end

	      end

	      task_name = "" if line.strip.empty?
	    }

	    @project_list 					= generate_projects_list(project_list)
	    @task_list  						= split_list_into_lines(task_list)
	    @not_found_project_list = split_list_into_lines(not_found_project_list)

	  end

	  def save_file(file_name, content)
	    File.open(File.join(@export_path, file_name), "w") {|file| file.puts content}
	  end

	  def file_exists?(file_name)
	    unless File.exists?(file_name)
	      @missing_files_list << file_name
	      @files_verified = false
	    end
	  end

end

JournyX2QuickBooks.new.run

require 'mechanize'
require 'json'
require 'ox'

class HrmosParser
  SITE_URL = 'https://hrmos.co/pages/zimmerbiomet/jobs'

  def generate_xml(path)
    doc = Ox::Document.new(:version => '1.0')
    jobs = get_jobs
    jobs_count = jobs.nodes.count
    source = Ox::Element.new('source')
    source << (Ox::Element.new('jobs_count') << jobs_count.to_s)
    source << (Ox::Element.new('generation_time') << Time.now.utc.strftime('%m/%d/%Y %H:%M %p'))
    source << jobs
    doc << source
    xml = Ox.dump(doc)
    File.write(path + '//file.xml', xml, mode: 'w')
  end

  private

  def get_jobs
    jobs = Ox::Element.new('jobs')
    @mechanize = Mechanize.new
    get_links(SITE_URL).each do |link|
      jobs << get_job(link)
    end
    jobs
  end

  def get_job(link)
    parameters = get_parameters(link)
    job = Ox::Element.new('job')
    parameters.keys.each do |key|
      job << (Ox::Element.new(key) << parameters[key])
    end
    job
  end

  def get_parameters(link)
    page = @mechanize.get(link)
    type_name = "application/ld+json"
    node = page.at_xpath("//script[@type=\"#{type_name}\"]")
    json = JSON.parse(node)
    full_address = json["jobLocation"].last["address"]
    Hash[
      title: json["title"],
      url: link,
      job_reference: link.split('/')[-1],
      street: full_address["streetAddress"],
      city: full_address["addressLocality"],
      state: full_address["addressRegion"],
      location: full_address["streetAddress"] + ', ' +
        full_address["addressLocality"] + ', ' +
        full_address["addressRegion"],
      body: json["description"],
      company: json["hiringOrganization"]["name"],
      posted_at: json["datePosted"]
    ]
  end

  def get_links(link)
    links = Array.new
    page = @mechanize.get(link)
    class_name = "pg-list-cassette jsc-joblist-cassette"
    page.xpath("//li[@class=\"#{class_name}\"]").each do |node|
      links.push(node.search('a').attr('href').to_s)
    end
    links
  end
end
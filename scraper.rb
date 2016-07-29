#!/bin/env ruby
# encoding: utf-8

# Kazakhstan Mazhilis scraper

require 'rubygems'
require 'bundler/setup'

require 'pry'

require 'nokogiri'
require 'open-uri/cached'
require 'scraperwiki'

OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def page_for(url)
  Nokogiri::HTML(open(url).read)
end

def index_pages(base_url)
	index_pages = []
	('a'..'z').to_a.each do |letter|
		page = page_for("#{base_url}#{letter}")
		index_pages.push(page)
	end
	index_pages
end

def scrape_index_page_details_for(person)
	deputat = {}

	deputat[:name] = person.css('div.col-md-8').css('a.links').text.tidy
	deputat[:summary] = person.css('div.col-md-8').css('span').text.tidy

	bio_page_uri = person.css('div.col-md-8').css('a.links')[0]['href'].sub('/ru','').tidy
	deputat[:bio_page_russian] = "#{$base_url}/ru#{bio_page_uri}".tidy
	deputat[:bio_page_kazakh] = "#{$base_url}/kk#{bio_page_uri}".tidy

	image = person.css('div.col-md-4').css('a.links').css('img').attr('src')
	deputat[:image] = "#{$base_url}#{image}"

	deputat[:id] = "#{$base_url}/kk#{bio_page_uri}".tidy.split('/').last

	deputat
end

def deputats_on(page)
	deputats_on_page = page.css('div.deputy-persons')
	data = deputats_on_page.map do |person|
		scrape_index_page_details_for(person)
	end
	data
end

$base_url = ("http://www.parlam.kz")
pages = index_pages("http://www.parlam.kz/en/mazhilis/People/DeputyList/")
deputats = pages.map { |page| deputats_on(page) }.flatten

deputats = deputats.map do |person|
	#get russian bio url
	page = page_for(person[:bio_page_russian])
	bio = page.css('div.bio')
	person[:name_russian] = bio.css('h2').text
	person[:summary_russian] = bio.css('p').text
	#get kazakh url
	page = page_for(person[:bio_page_kazakh])
	bio = page.css('div.bio')
	person[:name_kazakh] = bio.css('h2').text
	person[:summary_kazakh] = bio.css('p').text
	person[:term] = 'term/6'
	person
end

terms = [
  { 
    id: 'term/6',
    name: 'Sixth Convocation',
    start_date: '2016-03-20'
  }
]


deputats.each do |data|
	ScraperWiki.save_sqlite([:id, :name], data)
end

ScraperWiki.save_sqlite(terms)



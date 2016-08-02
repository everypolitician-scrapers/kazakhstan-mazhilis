#!/bin/env ruby
# encoding: utf-8

# Kazakhstan Mazhilis scraper

require 'rubygems'
require 'bundler/setup'

require 'pry'

require 'nokogiri'
require 'open-uri/cached'
require 'scraperwiki'
require 'scraped_page_archive'

OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def generate_id_from(str)
  arr = str.split('')
  arr.map! do |i|
    i.ord
  end
  arr.join
end

def page_for(url)
  response = open(url)
  Nokogiri::HTML(response.read)
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
  deputat[:website] = "#{$base_url}/ru#{bio_page_uri}".tidy
  deputat[:website__ru] = "#{$base_url}/ru#{bio_page_uri}".tidy
  deputat[:website__kk] = "#{$base_url}/kk#{bio_page_uri}".tidy

  image = person.css('div.col-md-4').css('a.links').css('img').attr('src')
  deputat[:image] = "#{$base_url}#{image}"

  deputat[:id] = generate_id_from("#{$base_url}/kk#{bio_page_uri}".tidy.split('/').last)

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
  page = page_for(person[:website__ru])
  bio = page.css('div.bio')
  name_ru = bio.css('h2')
  name_ru.css('br').each { |br| br.replace(' ') }
  person[:name__ru] = name_ru.text
  person[:summary__ru] = bio.css('p').text

  #get kazakh url
  page = page_for(person[:website__kk])
  bio = page.css('div.bio')
  name_kk = bio.css('h2')
  name_kk.css('br').each { |br| br.replace(' ') }
  person[:name__kk] = name_kk.text
  person[:summary__kk] = bio.css('p').text
  person[:term] = 6
  person
end

deputats.each do |data|
  ScraperWiki.save_sqlite([:id, :name], data)
end


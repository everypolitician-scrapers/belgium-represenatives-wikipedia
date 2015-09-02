#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
  # Nokogiri::HTML(open(url).read, nil, 'utf-8')
end

def scrape_list(url)
  noko = noko_for(url)
  binding.pry
  noko.xpath('//h2[contains(.,"Lijst van volksvertegenwoordigers")]/following-sibling::table[1]/tr[td]').each do |tr|
    tds = tr.css('td')
    data = { 
      name: tds[0].css('a').text,
      wikiname__nl: tds[0].css('a/@title').text,
      party: tds[1].text.tidy,
      area: tds[2].text.tidy,
      taalgroep: tds[3].text.tidy,
      term: '54',
      source: url,
    }
    puts data
    # ScraperWiki.save_sqlite([:wikiname__nl, :term], data)
  end
end

scrape_list('https://nl.wikipedia.org/wiki/Kamer_van_Volksvertegenwoordigers_(samenstelling_2014-2019)')

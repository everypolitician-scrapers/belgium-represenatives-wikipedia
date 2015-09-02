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

@MONTHS = %w(0 1 2 3 april mei 6 juli 8 9 oktober 11 12)
def date_from(str)
  d, m, y = str.split(/ /)
  return "%d-%02d-%02d" % [y, @MONTHS.find_index(m), d]
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
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

    if tds[4] && tds[4].text.tidy.include?('vervangt vanaf')
      date = date_from(tds[4].text[/vervangt vanaf (\d+ \w+ \d+)/, 1])
      who = tds[4].css('a').first
      replaced = data.merge({
        name: who.text,
        wikiname__nl: who.attr('title'),
        end_date: date,
      })
      data[:start_date] = date
      ScraperWiki.save_sqlite([:wikiname__nl, :term], replaced)
    end
    ScraperWiki.save_sqlite([:wikiname__nl, :term], data)
  end
end

scrape_list('https://nl.wikipedia.org/wiki/Kamer_van_Volksvertegenwoordigers_(samenstelling_2014-2019)')

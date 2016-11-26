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

@MONTHS = %w(0 1 2 3 april mei juni juli 8 september oktober november 12)
def date_from(str)
  d, m, y = str.split(/ /)
  return "%d-%02d-%02d" % [y, @MONTHS.find_index(m), d] rescue abort "Unknown month: #{m}"
end

# Hard-code some hard-to-parse mid-term changes
WILMES =   { name: 'Sophie Wilmès', wikiname__nl: 'Sophie Wilmès', start_date: '2014-10-11', end_date: '2015-09-22' }
REYNDERS = { name: 'Didier Reynders', wikiname__nl: 'Didier Reynders', end_date: '2014-10-11' }
WILRYCX =  { name: 'Frank Wilrycx', wikiname__nl: 'Frank Wilrycx', start_date: '2014-07-30', end_date: '2016-04-29' }

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
  rows = noko.xpath('//h2[contains(.,"Lijst van volksvertegenwoordigers")]/following-sibling::table[1]/tr[td]')
  abort "No rows" if rows.empty?
  rows.each do |tr|
    tds = tr.css('td')
    data = {
      name: tds[0].css('a').text,
      wikiname__nl: tds[0].css('a/@title').text,
      party: tds[1].text.tidy,
      area: tds[2].text.tidy,
      language_group: tds[3].text.tidy,
      term: '54',
      start_date: '2014-06-19',
    }

    if tds[4] && !(notes = tds[4].text.tidy).empty?
      if notes.include? 'vervangt vanaf 22 september 2015 Sophie Wilmès, die minister wordt in de federale regering-Michel. Wilmès zelf verving vanaf 11 oktober 2014 Didier Reynders, die ook minister in de regering-Michel werd'
        wilmes = data.merge(WILMES)
        reynders = data.merge(REYNDERS)
        data[:start_date] = wilmes[:end_date]
        ScraperWiki.save_sqlite([:wikiname__nl, :term, :start_date], wilmes)
        ScraperWiki.save_sqlite([:wikiname__nl, :term, :start_date], reynders)

      elsif notes.include? 'werd van 30 juli 2014 tot 29 april 2016 als minister in de Vlaamse regering-Bourgeois vervangen door Frank Wilrycx'
        wilryxc = data.merge(WILRYCX)
        turtelboom_first = data.clone.merge(end_date: wilryxc[:start_date])
        data[:start_date] = wilryxc[:end_date]
        ScraperWiki.save_sqlite([:wikiname__nl, :term, :start_date], wilryxc)
        ScraperWiki.save_sqlite([:wikiname__nl, :term, :start_date], turtelboom_first)

      elsif notes.include?('vervangt vanaf')
        date = date_from(notes[/vervangt vanaf (\d+ \w+ \d+)/, 1]) or raise binding.pry
        who = tds[4].css('a').first
        replaced = data.merge({
          name: who.text,
          wikiname__nl: who.attr('title'),
        })
        data[:start_date] = replaced[:end_date] = date
        ScraperWiki.save_sqlite([:wikiname__nl, :term, :start_date], replaced)
      else
        warn "Unparsed notes: #{notes}"
      end
    end

    ScraperWiki.save_sqlite([:wikiname__nl, :term, :start_date], data)
  end
end

# Always start empty
ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
scrape_list('https://nl.wikipedia.org/wiki/Kamer_van_Volksvertegenwoordigers_(samenstelling_2014-2019)')

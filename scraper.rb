#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'scraped'
require 'scraperwiki'
require 'pry'

@MONTHS = %w(0 januari 2 maart april mei juni juli 8 september oktober november 12)
def date_from(str)
  d, m, y = str.split(/ /)
  return '%d-%02d-%02d' % [y, @MONTHS.find_index(m), d] rescue abort "Unknown month: #{m}"
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
  rows = noko.xpath('//h2[contains(.,"Lijst van volksvertegenwoordigers")]/following-sibling::table[1]/tr[td]')
  abort 'No rows' if rows.empty?
  rows.each do |tr|
    tds = tr.css('td')
    data = {
      name:           tds[0].css('a').text,
      wikiname__nl:   tds[0].css('a/@title').text,
      party:          tds[1].text.tidy,
      area:           tds[2].text.tidy,
      language_group: tds[3].text.tidy,
      term:           '54',
      start_date:     '2014-06-19',
      source:         url,
    }

    # Temporary replacements
    if tds[4] && !(notes = tds[4].text.tidy).empty?
      # Gautier Calomne replacing Sophie Wilmès replacing Didier Reynders
      if notes.include? 'vervangt vanaf 22 september 2015 Sophie Wilmès, die minister wordt in de federale regering-Michel. Wilmès zelf verving vanaf 11 oktober 2014 Didier Reynders'
        wilmes   = { name: 'Sophie Wilmès', wikiname__nl: 'Sophie Wilmès', start_date: '2014-10-11', end_date: '2015-09-22' }
        reynders = { name: 'Didier Reynders', wikiname__nl: 'Didier Reynders', end_date: '2014-10-11' }
        wilmes_m = data.merge(wilmes)
        reyn_m   = data.merge(reynders)
        data[:start_date] = wilmes[:end_date]
        ScraperWiki.save_sqlite(%i(wikiname__nl term start_date), wilmes_m)
        ScraperWiki.save_sqlite(%i(wikiname__nl term start_date), reyn_m)

      # Vincent Van Peteghem replacing Sarah Claerhout replacing Pieter De Crem
      elsif notes.include? 'vervangt vanaf 10 november 2016 Sarah Claerhout, die uit CD&V stapt en haar zetel aan haar partij teruggeeft. Claerhout zelf verving 14 oktober 2014 Pieter De Crem'
        claerhout = { name: 'Sarah Claerhout', wikiname__nl: 'Sarah Claerhout', start_date: '2014-10-14', end_date: '2016-11-10' }
        decrem    = { name: 'Pieter De Crem', wikiname__nl: 'Pieter De Crem', end_date: '2014-10-14' }
        claer_m   = data.merge(claerhout)
        decrem_m  = data.merge(decrem)
        data[:start_date] = claerhout[:end_date]
        ScraperWiki.save_sqlite(%i(wikiname__nl term start_date), claer_m)
        ScraperWiki.save_sqlite(%i(wikiname__nl term start_date), decrem_m)

      # Annemie Turtelboom temporarily replaced by Frank Wilrycx
      elsif notes.include? 'werd van 30 juli 2014 tot 29 april 2016 als minister in de Vlaamse regering-Bourgeois vervangen door Frank Wilrycx'
        wilrycx = { name: 'Frank Wilrycx', wikiname__nl: 'Frank Wilrycx', start_date: '2014-07-30', end_date: '2016-04-29' }
        wil_m   = data.merge(wilrycx)
        turtelboom_first = data.clone.merge(end_date: wilrycx[:start_date])
        data[:start_date] = wilrycx[:end_date]
        ScraperWiki.save_sqlite(%i(wikiname__nl term start_date), wil_m)
        ScraperWiki.save_sqlite(%i(wikiname__nl term start_date), turtelboom_first)

      elsif notes.include?('vervangt vanaf')
        date = date_from(notes[/vervangt vanaf (\d+ \w+ \d+)/, 1]) or raise binding.pry
        who = tds[4].css('a').first
        replaced = data.merge(name:         who.text,
                              wikiname__nl: who.attr('title'))
        data[:start_date] = replaced[:end_date] = date
        ScraperWiki.save_sqlite(%i(wikiname__nl term start_date), replaced)

      # Annick Lambrecht replacing Johan Vande Lanotte
      elsif notes.include?('Vervangt vanaf 12 januari 2017 Johan Vande Lanotte, die voltijds burgemeester van Oostende wordt')
        date = date_from(notes[/vervangt vanaf (\d+ \w+ \d+)/i, 1]) or raise binding.pry
        who = tds[4].css('a').first
        replaced = data.merge(name:         who.text,
                              wikiname__nl: who.attr('title'))
        data[:start_date] = replaced[:end_date] = date
        ScraperWiki.save_sqlite(%i(wikiname__nl term start_date), replaced)

      else
        warn "Unparsed notes: #{notes}"
      end
    end

    puts data.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']
    ScraperWiki.save_sqlite(%i(wikiname__nl term start_date), data)
  end
end

# Always start empty
ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
scrape_list('https://nl.wikipedia.org/wiki/Kamer_van_Volksvertegenwoordigers_(samenstelling_2014-2019)')

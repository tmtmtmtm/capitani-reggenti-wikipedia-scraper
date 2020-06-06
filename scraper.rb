#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require_relative 'lib/unspan_all_tables'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class HoldersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links
  decorator UnspanAllTables

  field :holders do
    semesters.flat_map do |semester|
      [
        semester.slice(:name, :id, :start_date, :end_date),
        semester.slice(:name2, :id2, :start_date, :end_date).transform_keys { |k| k.to_s.chomp('2').to_sym },
      ]
    end
  end

  private

  def semester_rows
    noko.xpath('//table[.//th[contains(.,"Semestre")]]//tr[td]')
  end

  def semesters
    semester_rows.map { |tr| fragment(tr => SemesterRow).to_h }
  end
end

class SemesterRow < Scraped::HTML
  field :name do
    tds[2].text.tidy
  end

  field :id do
    tds[2].xpath('.//a/@wikidata').text
  end

  field :name2 do
    tds[3].text.tidy
  end

  field :id2 do
    tds[3].xpath('.//a/@wikidata').text
  end

  field :start_date do
    Date.new(year, start_month, 1)
  end

  field :end_date do
    start_date >> 6
  end

  private

  def tds
    noko.css('td')
  end

  def year
    tds[0].text.tidy.to_i
  end

  def semester
    tds[1].text.tidy
  end

  def start_month
    return 4 if semester == 'aprile'
    return 10 if semester == 'ottobre'
    raise "Unknown semester: #{semester}"
  end
end

url = 'https://it.wikipedia.org/wiki/Capitani_reggenti_dal_2001'
Scraped::Scraper.new(url => HoldersPage).store(:holders)

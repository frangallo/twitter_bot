require 'openai'
require 'twitter'
require 'httparty'
require_relative 'openai_services'
require_relative 'twitter_service'


class GospelPrayerService

  def main
    puts 'Fetching the daily gospel...'
    gospel = fetch_gospel
    puts "Gospel: #{gospel[:text]}"

    puts 'Generating prayer...'
    prayer_prompt = "Generate a prayer based on the given daily Catholic gospel, tailored for millennials and younger generations to share on Twitter.
    Keep it under 280 characters, starting with 'Dear Lord,' followed by a new line, and ending with a new line, 'Amen,' and the prayer emoji.
    The tone should vary, including casual, inspirational, modern, and reflective elements. :\n Gospel:\n #{gospel[:text]}"
    prayer = gpt4_request(prayer_prompt)
    puts "Prayer: #{prayer.inspect}"

    puts 'Posting the tweet...'
    TwitterService.post_tweet_without_image_or_opening_ling(prayer)
    puts 'Tweet posted!'
    rescue StandardError => e
      Rails.logger.error "Error in main: #{e.message}"
      puts "Error in main: #{e.message}"
  end

  def fetch_gospel
    url = 'https://bible.usccb.org/daily-bible-reading'
    parsed_page = fetch_page(url)
    gospel_header = find_gospel_header(parsed_page)

    if gospel_header
      content_body = find_gospel(gospel_header, 'content-body')
      gospel_verse = find_gospel_verse(gospel_header, 'address')
    end

    if content_body
      gospel_text = content_body.inner_text.strip
      {verse: gospel_verse, text: gospel_text }
    else
      Rails.logger.error "Error fetching daily gospel: content_body not found"
      nil
    end
    rescue StandardError => e
      Rails.logger.error "Error fetching daily gospel: #{e.message}"
      nil
  end

  private

  def fetch_page(url)
    response = HTTParty.get(url)
    Nokogiri::HTML(response.body)
  end

  def find_gospel_header(parsed_page)
    parsed_page.css('.name').find { |header| header.content.match?(/^\s*Gospel\s*$/) }
  end

  def find_gospel(header, html_class)
    current_node = header.parent
    while current_node = current_node.next_element
      return current_node if current_node['class'] == html_class
    end

    nil
  end

  def find_child_with_class(parent, class_name)
    parent.children.find { |child| child['class'] == class_name }
  end

  def find_gospel_verse(header, class_name)
    address_node = find_child_with_class(header.parent, class_name)
    return address_node.inner_text.strip if address_node

    nil
  end


  def gpt4_request(prompt)
    OpenaiServices::ChatgptService.call(prompt)
  end

  def dalle_request(prompt)
    OpenaiServices::DalleService.call(prompt)
  end

end

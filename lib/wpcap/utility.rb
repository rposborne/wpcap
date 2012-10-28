class Wpcap::Utility
  
  def self.error(text)
    puts red("****#{text}****")
  end
  
  def self.colorize(text, color_code)
    "\e[#{color_code}m#{text}\e[0m"
  end

  def self.red(text); self.colorize(text, 31); end
  def self.green(text); self.colorize(text, 32); end

end
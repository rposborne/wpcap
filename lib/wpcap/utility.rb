class Wpcap::Utility
  
  def self.error(text)
    puts red("****#{text}****")
  end
  
  def self.question(text)
    puts blue("****#{text}****")
  end
  
  def self.success(text)
    puts green("****#{text}****")
  end
  
  def self.colorize(text, color_code)
    "\033[1m\e[#{color_code}m#{text}\e[0m\033[22m"
  end

  def self.red(text); self.colorize(text, 31); end
  def self.green(text); self.colorize(text, 32); end
  def self.blue(text); self.colorize(text, 34); end
  
end

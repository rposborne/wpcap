class Wpcap::Backup
  
  def initialize(ls)
    @data ||= ls.split(" ")
  end
  
  def name
    @name ||= @data[8]  
  end  
  
  def type
    type = name.split(".")[0]
    @type ||= "#{type} " 
  end
  
  def size
    as_size( @data[4] )
  end
  
  def at
    Time.at("#{name.chomp(".sql.bz2").split(".")[1]}.#{name.chomp(".sql.bz2").split(".")[2]}".to_f).strftime("%c")
  end

  def self.parse(ls_output)
    backups = []
    ls_output.each_line do |line|
      
      backups << Wpcap::Backup.new( line ) unless line.include?("total")
    end
    return backups
  end
  
  
  PREFIX = %W(TiB GiB MiB KiB B).freeze

  def as_size( s )
    s = s.to_f
    i = PREFIX.length - 1
    while s > 512 && i > 0
      i -= 1
      s /= 1024
    end
    ((s > 9 || s.modulo(1) < 0.1 ? '%d' : '%.1f') % s) + ' ' + PREFIX[i]
  end
  
end

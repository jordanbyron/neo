require 'rubygems'
require 'mechanize'
require 'yaml'

class Neo
  def initialize
    @config = YAML.load_file("twitter.yml")

    @agent = Mechanize.new { |a| a.follow_meta_refresh = true }

    #Login

    page = @agent.get("http://reddirtrubyconf.com/auth/twitter")

    form = page.forms.first
    form.field_with(:name => "session[password]").value = @config["password"]
    form.field_with(:name => "session[username_or_email]").value = @config["username"]

    @agent.submit(form)
    
    @game = @agent.get("http://reddirtrubyconf.com/game")
    
    @attack = 9
    @loaded = 0
    @attack_only = false
  end
  
  def create_character
    character_form = @game.forms.first

    character_form["character[name]"] = "JordanByron_#{rand(99999)}"

    @game = @agent.submit(character_form)
    
    select_battle
  end
  
  def select_battle
    while !fighting?
      if !difficulty[/(easy)|(fair)/]
        sleep 1
        begin
          @game = @game.link_with(:href => /move=run/).click  # This randomly doesn't work :-/
        rescue
          @game = @agent.get("http://reddirtrubyconf.com/game")
          puts "Damn link!"
        end
      else
        load_program
      end
    end
    
    do_battle
  end
  
  def do_battle
    if state != :battle
      return
    end
    
    my_moves, enemy_moves   = moves
    my_hp, enemy_hp         = hp
    my_rating, enemy_rating = rating
    
    puts "-----------"

    puts "#{my_moves.first} VS #{enemy_moves.first}"
    puts "#{my_hp} VS #{enemy_hp}"
    
    if my_hp - enemy_hp < 0
      puts "\e[0;31m#{enemy_hp} higher than #{my_hp}!!!!\e[0m"
    end
    
    if enemy_moves.first && enemy_moves.first.include?("H")
      @attack_only = true
    end

    if @attack_only      
      if @first_move || my_moves.length == 0
        load_program
      else
        execute
        puts "EXECUTE"
      end
      
    else
      if enemy_moves.first && !enemy_moves.first.include?("A")
        load_program
        puts "\e[0;31m#{enemy_moves.first} LOADED\e[0m"
      elsif @loaded >= 2 && my_hp <= 8 && my_hp <= enemy_hp && enemy_rating.first && enemy_rating.first.first <= 1
        load_program
        puts "\e[0;31mAdvancing to gain ground\e[0m"
      elsif my_moves.length == 0
        load_program
      else
        execute
        puts "EXECUTE"
      end
    end
    
    @first_move = false
  end
  
  def matz
    if @attack < 9
      @game = @game.link_with(:href => /move=A/).click
      @attack += 1
    else
      @game = @game.link_with(:href => /move=HP/).click
    end
    
    
    select_battle
  end
  
  def fight
    
    case state
      when :new_character   then create_character
      when :fight_or_flight then select_battle
      when :round_ended     then next_encounter; select_battle
      when :battle          then do_battle
      when :matz            then matz
      when :unknown         then raise "Unknown"
    end
    
  end
  
  def fighting?
    !!@game.search("div[id=moves]").to_s[/HP/]
  end
  
  def execute
    @game = @game.link_with(:href => /move=execute/).click
  end
  
  def next_encounter
    @first_move = true
    puts "\e[0;32mYOU KILLED ANOTHER DUDE!!!\e[0m"
    @game = @game.link_with(:href => /encounter/).click
  end
  
  def difficulty
    @game.search("div[id=moves]/p:first/b").to_s.strip
  end
  
  def moves
    moves = @game.search("div[id=moves]/p:last").to_s.split("<br>")
    moves.map {|move| move.scan(/[ADH]{3}/) }
  end
  
  def hp  
    @game.search("div[id=moves]/p").to_s.scan(/:\s*(\d*)HP/).map {|hp| hp.join.to_i }
  end
  
  def rating
    moves.map do |move_set|
      move_set.map do |move| 
        d, ah = move.chars.partition { |x| x == "D" }
        a, h  = ah.partition { |x| x == "A" }
        
        [d.count, a.count, h.count]
      end
    end
  end
  
  def state    
    if @game.search("input[id=character_name]").length > 0
      :new_character
    elsif @game.search("div[id=moves]/p").to_s[/This fight looks/]
      :fight_or_flight
    elsif @game.search("div[id=moves]/p").to_s[/died/]
      :round_ended
    elsif @game.search("div[id=moves]/p").to_s[/Ruby mastery/]
      :matz
    elsif @game.search("div[id=moves]/p").to_s[/You:\s*(\d*)HP/]
      :battle
    else
      :unknown
    end
  end
  
  def load_program(attack=6, defend=nil)
    defend = 9 - @attack unless defend
    
    battle = @game.forms.first
    
    battle["program_attack"]  = @attack
    battle["program_defense"] = defend
    
    @game = @agent.submit(battle)
    
    puts "\e[0;34mReloaded with attack=#{@attack} defend=#{defend}\e[0m"
    
    @loaded = 0
  end

end

begin
  n = Neo.new
  
  loop do
    n.fight
  end
end
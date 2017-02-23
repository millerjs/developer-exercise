class BlackjackPlayerException < StandardError
  attr_reader :player

  def initialize(player)
    @player = player
  end
end

# Player (but not dealer) wins immediately
class PlayerBlackjacked < BlackjackPlayerException
  def to_s
    "Player #{@player} blackjacked!"
  end
end

# Player loses immediately
class PlayerBust < BlackjackPlayerException
  def to_s
    "Player #{@player} bust!"
  end
end

class Card
  attr_accessor :suite, :name, :value

  def initialize(suite, name, value)
    @suite, @name, @value = suite, name, value
  end
end

class Deck
  attr_accessor :playable_cards
  SUITES = [:hearts, :diamonds, :spades, :clubs]
  NAME_VALUES = {
    :two   => 2,
    :three => 3,
    :four  => 4,
    :five  => 5,
    :six   => 6,
    :seven => 7,
    :eight => 8,
    :nine  => 9,
    :ten   => 10,
    :jack  => 10,
    :queen => 10,
    :king  => 10,
    :ace   => [11, 1]}

  def initialize
    shuffle
  end

  def deal_card
    random = rand(@playable_cards.size)
    @playable_cards.delete_at(random)
  end

  def shuffle
    @playable_cards = []
    SUITES.each do |suite|
      NAME_VALUES.each do |name, value|
        @playable_cards << Card.new(suite, name, value)
      end
    end
  end
end

class Hand
  attr_accessor :cards

  def initialize
    @cards = []
  end

  # Returns unique, sorted possible total card values for hand
  def possible_values
    totals = [0]
    @cards.each do |card|
      if card.value.is_a?(Array)
        totals = totals.map {|total| card.value.map {|value| total + value}}
        totals = totals.flatten.sort.uniq
      else
        totals = totals.map {|original| original + card.value}
      end
    end
    totals.sort.uniq
  end

  # Returns true if player is bust
  def bust?
    possible_values.all? {|value| value > 21 }
  end

  # Returns true if player has blackjack
  def blackjack?
    aces = @cards.select {|card| card.name == :ace}
    facecards = @cards.select {|card| card.value == 10}
    aces.count == 1 && facecards.count == 1
  end

  # Returns max value that is not bust
  def best_value
    possible_values.select {|value| value <= 21 }.max
  end
end

class Player
  def initialize(dealer)
    @dealer = dealer
    @hand = Hand.new
  end

  # Raises exception if card dealt causes bust or blackjack
  def deal(card)
    @hand.cards << card
    if bust?
      raise PlayerBust.new(self)
    elsif blackjack? && !@dealer.blackjack?
      raise PlayerBlackjacked.new(self)
    end
  end

  # Proxy attribute so we don't have to make @hand public
  def bust?
    @hand.bust?
  end

  # Proxy attribute so we don't have to make @hand public
  def blackjack?
    @hand.blackjack?
  end

  # The score is very informative and really shouldn't be public, but
  # since the Game object has to know who won, we need to be able to
  # access the player's score.  To counteract this, raise an exception
  # if the score is requested but the player still wants to hit
  def score
    if hit? && !bust? && !blackjack?
      raise RuntimeError.new("Score was accessed before #{self} was done.")
    end
    @hand.best_value
  end

  # Some quick player pseudo-logic to when to hit:
  # * value of hand < 16
  # * if value of hand < 19 and contains an ace
  # * if value of hand < 19 and dealer is showing an ace
  def hit?
    if @hand.best_value < 16
      true
    elsif @hand.best_value < 19 && @hand.cards.any? { |card| card.name == :ace }
      true
    elsif @hand.best_value < 19 && @dealer.showing.name == :ace
      true
    end
  end
end

class Dealer < Player
  def initialize
    @hand = Hand.new
  end

  # Raises exception if card dealt causes bust
  def deal(card)
    @hand.cards << card
    if bust?
      raise PlayerBust.new(self)
    end
  end

  def showing
    @hand.cards[0]
  end

  def hit?
    @hand.best_value < 17
  end
end

class Game
  # Simulates a game and prints results
  def simulate
    deck = Deck.new
    dealer = Dealer.new
    player = Player.new(dealer)

    begin
      dealer.deal(deck.deal_card)
      player.deal(deck.deal_card)
      dealer.deal(deck.deal_card)
      player.deal(deck.deal_card)

      while player.hit?
        player.deal(deck.deal_card)
      end

      while dealer.hit?
        dealer.deal(deck.deal_card)
      end

      if player.score > dealer.score
        puts "Player #{player} wins #{player.score} to #{dealer.score}!"
      elsif player.score < dealer.score
        puts "Dealer #{dealer} wins #{dealer.score} to #{player.score}!"
      else
        puts "Player #{player} tied Dealer #{dealer} at #{player.score}"
      end

    rescue BlackjackPlayerException => exception
      puts "#{exception}"
    end
  end

end


require 'test/unit'

class CardTest < Test::Unit::TestCase
  def setup
    @card = Card.new(:hearts, :ten, 10)
  end

  def test_card_suite_is_correct
    assert_equal @card.suite, :hearts
  end

  def test_card_name_is_correct
    assert_equal @card.name, :ten
  end
  def test_card_value_is_correct
    assert_equal @card.value, 10
  end
end

class DealerTest < Test::Unit::TestCase
  def setup
    @five = Card.new(:hearts, :five, 5)
    @seven = Card.new(:hearts, :seven, 7)
    @jack = Card.new(:hearts, :jack, 10)
    @ace = Card.new(:hearts, :ace, [11, 1])
  end

  def test_dealer_showing
    dealer = Dealer.new
    [@five, @seven, @ace].map { |card| dealer.deal(card) }
    assert_equal dealer.showing, @five
  end

  def test_player_doesnt_raise_player_blackjacked
    dealer = Dealer.new
    dealer.deal(@jack)
    dealer.deal(@ace)
  end

end

class PlayerTest < Test::Unit::TestCase
  def setup
    @five = Card.new(:hearts, :five, 5)
    @jack = Card.new(:hearts, :jack, 10)
    @ace = Card.new(:hearts, :ace, [11, 1])
  end

  def test_player_raises_player_bust
    player = Player.new(nil)
    (0..3).map { |_| player.deal(@five) }
    assert_raise PlayerBust do
      player.deal(@five)
    end
  end

  def test_player_disallows_score_before_complete
    player = Player.new(nil)
    assert_raise RuntimeError do
      player.score
    end
  end

  def test_player_raises_player_blackjacked
    player = Player.new(Dealer.new)
    player.deal(@jack)
    assert_raise PlayerBlackjacked do
      player.deal(@ace)
    end
  end
end

class HandTest < Test::Unit::TestCase
  def setup
    @five = Card.new(:hearts, :five, 5)
    @seven = Card.new(:hearts, :seven, 7)
    @jack = Card.new(:hearts, :jack, 10)
    @ace = Card.new(:hearts, :ace, [11, 1])
  end

  def test_hand_single_possible_value
    hand = Hand.new
    hand.cards += [@five, @seven]
    assert_equal hand.possible_values, [12]
  end

  def test_hand_two_possible_values
    hand = Hand.new
    hand.cards += [@five, @ace]
    assert_equal hand.possible_values, [6, 16]
  end

  def test_hand_three_possible_values
    hand = Hand.new
    hand.cards += [@five, @ace, @ace]
    assert_equal hand.possible_values, [7, 17, 27]
  end

  def test_hand_is_bust
    hand = Hand.new
    hand.cards += [@seven, @five, @seven, @five]
    assert_equal hand.bust?, true
  end

  def test_hand_is_blackjack
    hand = Hand.new
    hand.cards += [@ace, @jack]
    assert_equal hand.blackjack?, true
  end

  def test_hand_is_not_blackjack
    hand = Hand.new
    hand.cards += [@ace, @seven]
    assert_equal hand.blackjack?, false
  end

  def test_hand_best_value
    hand = Hand.new
    hand.cards += [@seven, @five, @seven, @ace]
    assert_equal hand.best_value, 20
  end
end

class DeckTest < Test::Unit::TestCase
  def setup
    @deck = Deck.new
  end

  def test_new_deck_has_52_playable_cards
    assert_equal @deck.playable_cards.size, 52
  end

  def test_dealt_card_should_not_be_included_in_playable_cards
    card = @deck.deal_card
    assert_equal @deck.playable_cards.include?(card), false
  end

  def test_shuffled_deck_has_52_playable_cards
    @deck.shuffle
    assert_equal @deck.playable_cards.size, 52
  end
end

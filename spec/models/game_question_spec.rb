require 'rails_helper'

# Тестовый сценарий для модели игрового вопроса,
# в идеале весь наш функционал (все методы) должны быть протестированы.
RSpec.describe GameQuestion, type: :model do

  # задаем локальную переменную game_question, доступную во всех тестах этого сценария
  # она будет создана на фабрике заново для каждого блока it, где она вызывается
  let(:game_question) { FactoryGirl.create(:game_question, a: 2, b: 1, c: 4, d: 3) }

  # группа тестов на игровое состояние объекта вопроса
  context 'game status' do
    # тест на правильную генерацию хэша с вариантами
    it 'correct .variants' do
      expect(game_question.variants).to eq({'a' => game_question.question.answer2,
                                            'b' => game_question.question.answer1,
                                            'c' => game_question.question.answer4,
                                            'd' => game_question.question.answer3})
    end

    it 'correct .answer_correct?' do
      # именно под буквой b в тесте мы спрятали указатель на верный ответ
      expect(game_question.answer_correct?('b')).to be_truthy
    end

    # тест на ключ правильного ответа
    it 'correct .correct_answer_key' do
      expect(game_question.correct_answer_key).to eq('b')
    end
  end

  # тест на наличие методов делегатов .text и .level
  it 'correct .text and .level delegate' do
    expect(game_question.text).to eq(game_question.question.text)
    expect(game_question.level).to eq(game_question.question.level)
  end

  # help_hash у нас имеет такой формат:
  # {
  #   fifty_fifty: ['a', 'b'], # При использовании подсказски остались варианты a и b
  #   audience_help: {'a' => 42, 'c' => 37 ...}, # Распределение голосов по вариантам a, b, c, d
  #   friend_call: 'Василий Петрович считает, что правильный ответ A'
  # }
  #

  # Группа тестов на помощь игроку
  context 'user helpers' do
    # проверяем работоспосбность "помощи зала"
    it 'correct audience_help' do
      # сначала убедимся, в подсказках пока нет нужного ключа
      expect(game_question.help_hash).not_to include(:audience_help)
      # вызовем подсказку
      game_question.add_audience_help

      # проверим создание подсказки
      expect(game_question.help_hash).to include(:audience_help)

      # мы не можем знать распределение, но можем проверить хотя бы наличие нужных ключей
      ah = game_question.help_hash[:audience_help]
      expect(ah.keys).to contain_exactly('a', 'b', 'c', 'd')
    end
  end
end

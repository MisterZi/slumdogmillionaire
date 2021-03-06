require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryGirl.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }


  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создали игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
          change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
              change(Question, :count).by(0) # Game.count не должен измениться
          )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # тесты на основные методы доступа к состоянию
  context 'game state' do

    # предыдущий уровень
    it 'correct previous_level' do
      expect(game_w_questions.previous_level).to eq(game_w_questions.current_level - 1)
    end

    # текущий, еще неотвеченный вопрос игры
    it 'correct current_game_question' do
      expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions[game_w_questions.current_level])
    end

    # последний отвеченный вопрос игры
    it 'correct previous_game_question' do
      if game_w_questions.previous_level == -1
        expect(game_w_questions.previous_game_question).to eq(nil) # т.к. начало игры
      else
        expect(game_w_questions.previous_game_question).to eq(game_w_questions.game_questions[game_w_questions.previous_level])
      end
    end
  end


  # тесты на основную игровую логику
  context 'game mechanics' do

    # тесты на метод проверки правильных ответов
    context 'correct .answer_current_question!' do

      let(:q) { game_w_questions.current_game_question.correct_answer_key }

      # ответ дан после истечения времени
      it 'time_out' do
        game_w_questions.created_at = Time.now - 1.hour
        expect(game_w_questions.answer_current_question!(q)).to be_falsey
      end

      # ответ дан верный
      it 'answer_correct' do
        expect(game_w_questions.answer_current_question!(q)).to be_truthy
      end

      # ответ дан последний(на миллион)
      it 'answer_correct last' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max
        expect(game_w_questions.answer_current_question!(q)).to be_truthy
        expect(game_w_questions.status).to eq(:won)
      end

      # ответ дан неправильный
      it 'wrong answer' do
        expect(game_w_questions.answer_current_question!('wrong answer')).to be_falsey
      end
    end

    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    # тест метода take_money!
    it 'take_money! finishes the game' do
      # отвечаем на вопрос
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      #берем деньги
      game_w_questions.take_money!

      prize = game_w_questions.prize
      expect(prize).to be > 0

      # проверяем статус игры и баланс игрока
      expect(game_w_questions.status).to eq(:money)
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq(prize)
    end


    # тест метода status
    context 'status ' do
      # перед каждым тестом "завершаем игру"
      before(:each) do
        game_w_questions.finished_at = Time.now
        expect(game_w_questions.finished?).to be_truthy
      end

      it 'fail' do
        game_w_questions.is_failed = true
        expect(game_w_questions.status).to eq(:fail)
      end

      it 'timeout' do
        game_w_questions.is_failed = true
        game_w_questions.created_at = game_w_questions.finished_at - 1.hour
        expect(game_w_questions.status).to eq(:timeout)
      end

      it 'won' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
        expect(game_w_questions.status).to eq(:won)
      end

      it 'money' do
        expect(game_w_questions.status).to eq(:money)
      end
    end
  end
end

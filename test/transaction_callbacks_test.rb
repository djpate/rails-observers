require "helper"

class TransactionCallbacksTest < ActiveSupport::TestCase
  if respond_to?(:use_transactional_tests=)
    self.use_transactional_tests = false
  else
    self.use_transactional_fixtures = false
  end

  fixtures :topics

  class TopicWithCallbacks < ActiveRecord::Base
    self.table_name = :topics

    after_commit{|record| record.send(:do_after_commit, nil)}
    after_commit(:on => :create){|record| record.send(:do_after_commit, :create)}
    after_commit(:on => :update){|record| record.send(:do_after_commit, :update)}
    after_commit(:on => :destroy){|record| record.send(:do_after_commit, :destroy)}
    after_rollback{|record| record.send(:do_after_rollback, nil)}
    after_rollback(:on => :create){|record| record.send(:do_after_rollback, :create)}
    after_rollback(:on => :update){|record| record.send(:do_after_rollback, :update)}
    after_rollback(:on => :destroy){|record| record.send(:do_after_rollback, :destroy)}

    def history
      @history ||= []
    end

    def after_commit_block(on = nil, &block)
      @after_commit ||= {}
      @after_commit[on] ||= []
      @after_commit[on] << block
    end

    def after_rollback_block(on = nil, &block)
      @after_rollback ||= {}
      @after_rollback[on] ||= []
      @after_rollback[on] << block
    end

    def do_after_commit(on)
      blocks = @after_commit[on] if defined?(@after_commit)
      blocks.each{|b| b.call(self)} if blocks
    end

    def do_after_rollback(on)
      blocks = @after_rollback[on] if defined?(@after_rollback)
      blocks.each{|b| b.call(self)} if blocks
    end
  end

  def setup
    @first, @second = TopicWithCallbacks.find(1, 3).sort_by { |t| t.id }
  end

  def test_call_after_commit_after_transaction_commits
    @first.after_commit_block{|r| r.history << :after_commit}
    @first.after_rollback_block{|r| r.history << :after_rollback}

    @first.save!
    assert_equal [:after_commit], @first.history
  end

  def test_only_call_after_commit_on_update_after_transaction_commits_for_existing_record
    @first.after_commit_block(:create){|r| r.history << :commit_on_create}
    @first.after_commit_block(:update){|r| r.history << :commit_on_update}
    @first.after_commit_block(:destroy){|r| r.history << :commit_on_destroy}
    @first.after_rollback_block(:create){|r| r.history << :rollback_on_create}
    @first.after_rollback_block(:update){|r| r.history << :rollback_on_update}
    @first.after_rollback_block(:destroy){|r| r.history << :rollback_on_destroy}

    @first.save!
    assert_equal [:commit_on_update], @first.history
  end

  def test_only_call_after_commit_on_destroy_after_transaction_commits_for_destroyed_record
    @first.after_commit_block(:create){|r| r.history << :commit_on_create}
    @first.after_commit_block(:update){|r| r.history << :commit_on_update}
    @first.after_commit_block(:destroy){|r| r.history << :commit_on_destroy}
    @first.after_rollback_block(:create){|r| r.history << :rollback_on_create}
    @first.after_rollback_block(:update){|r| r.history << :rollback_on_update}
    @first.after_rollback_block(:destroy){|r| r.history << :rollback_on_destroy}

    @first.destroy
    assert_equal [:commit_on_destroy], @first.history
  end

  def test_only_call_after_commit_on_create_after_transaction_commits_for_new_record
    @new_record = TopicWithCallbacks.new(:title => "New topic", :written_on => Date.today)
    @new_record.after_commit_block(:create){|r| r.history << :commit_on_create}
    @new_record.after_commit_block(:update){|r| r.history << :commit_on_update}
    @new_record.after_commit_block(:destroy){|r| r.history << :commit_on_destroy}
    @new_record.after_rollback_block(:create){|r| r.history << :rollback_on_create}
    @new_record.after_rollback_block(:update){|r| r.history << :rollback_on_update}
    @new_record.after_rollback_block(:destroy){|r| r.history << :rollback_on_destroy}

    @new_record.save!
    assert_equal [:commit_on_create], @new_record.history
  end

  def test_call_after_rollback_after_transaction_rollsback
    @first.after_commit_block{|r| r.history << :after_commit}
    @first.after_rollback_block{|r| r.history << :after_rollback}

    Topic.transaction do
      @first.save!
      raise ActiveRecord::Rollback
    end

    assert_equal [:after_rollback], @first.history
  end

  def test_only_call_after_rollback_on_update_after_transaction_rollsback_for_existing_record
    @first.after_commit_block(:create){|r| r.history << :commit_on_create}
    @first.after_commit_block(:update){|r| r.history << :commit_on_update}
    @first.after_commit_block(:destroy){|r| r.history << :commit_on_destroy}
    @first.after_rollback_block(:create){|r| r.history << :rollback_on_create}
    @first.after_rollback_block(:update){|r| r.history << :rollback_on_update}
    @first.after_rollback_block(:destroy){|r| r.history << :rollback_on_destroy}

    Topic.transaction do
      @first.save!
      raise ActiveRecord::Rollback
    end

    assert_equal [:rollback_on_update], @first.history
  end

  def test_only_call_after_rollback_on_destroy_after_transaction_rollsback_for_destroyed_record
    @first.after_commit_block(:create){|r| r.history << :commit_on_create}
    @first.after_commit_block(:update){|r| r.history << :commit_on_update}
    @first.after_commit_block(:destroy){|r| r.history << :commit_on_update}
    @first.after_rollback_block(:create){|r| r.history << :rollback_on_create}
    @first.after_rollback_block(:update){|r| r.history << :rollback_on_update}
    @first.after_rollback_block(:destroy){|r| r.history << :rollback_on_destroy}

    Topic.transaction do
      @first.destroy
      raise ActiveRecord::Rollback
    end

    assert_equal [:rollback_on_destroy], @first.history
  end

  def test_only_call_after_rollback_on_create_after_transaction_rollsback_for_new_record
    @new_record = TopicWithCallbacks.new(:title => "New topic", :written_on => Date.today)
    @new_record.after_commit_block(:create){|r| r.history << :commit_on_create}
    @new_record.after_commit_block(:update){|r| r.history << :commit_on_update}
    @new_record.after_commit_block(:destroy){|r| r.history << :commit_on_destroy}
    @new_record.after_rollback_block(:create){|r| r.history << :rollback_on_create}
    @new_record.after_rollback_block(:update){|r| r.history << :rollback_on_update}
    @new_record.after_rollback_block(:destroy){|r| r.history << :rollback_on_destroy}

    Topic.transaction do
      @new_record.save!
      raise ActiveRecord::Rollback
    end

    assert_equal [:rollback_on_create], @new_record.history
  end

  def test_only_call_after_rollback_on_records_rolled_back_to_a_savepoint
    def @first.rollbacks(i=0); @rollbacks ||= 0; @rollbacks += i if i; end
    def @first.commits(i=0); @commits ||= 0; @commits += i if i; end
    @first.after_rollback_block{|r| r.rollbacks(1)}
    @first.after_commit_block{|r| r.commits(1)}

    def @second.rollbacks(i=0); @rollbacks ||= 0; @rollbacks += i if i; end
    def @second.commits(i=0); @commits ||= 0; @commits += i if i; end
    @second.after_rollback_block{|r| r.rollbacks(1)}
    @second.after_commit_block{|r| r.commits(1)}

    Topic.transaction do
      @first.save!
      Topic.transaction(:requires_new => true) do
        @second.save!
        raise ActiveRecord::Rollback
      end
    end

    assert_equal 1, @first.commits
    assert_equal 0, @first.rollbacks
    assert_equal 0, @second.commits
    assert_equal 1, @second.rollbacks
  end

  def test_only_call_after_rollback_on_records_rolled_back_to_a_savepoint_when_release_savepoint_fails
    def @first.rollbacks(i=0); @rollbacks ||= 0; @rollbacks += i if i; end
    def @first.commits(i=0); @commits ||= 0; @commits += i if i; end

    @first.after_rollback_block{|r| r.rollbacks(1)}
    @first.after_commit_block{|r| r.commits(1)}

    Topic.transaction do
      @first.save
      Topic.transaction(:requires_new => true) do
        @first.save!
        raise ActiveRecord::Rollback
      end
      Topic.transaction(:requires_new => true) do
        @first.save!
        raise ActiveRecord::Rollback
      end
    end

    assert_equal 1, @first.commits
    assert_equal 2, @first.rollbacks
  end
end

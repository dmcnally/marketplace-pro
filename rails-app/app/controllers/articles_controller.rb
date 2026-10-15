class ArticlesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  before_action :set_recording, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_article_creation, only: [ :new, :create ]
  before_action :authorize_article_editing, only: [ :edit, :update ]
  before_action :authorize_article_deletion, only: [ :destroy ]

  def index
    @recordings = if params[:q].present?
      recordings.kept.search(params[:q], recordable_type: "Article").order(created_at: :desc)
    else
      recordings.kept.articles.order(created_at: :desc)
    end
  end

  def show
  end

  def new
    @article = Article.new
  end

  def create # rubocop:todo Controllers/MultipleInstanceVariables
    @recording = recordings.build(recordable: Article.new(article_params))

    if @recording.save
      redirect_to @recording, notice: "Article was successfully created."
    else
      @article = @recording.recordable
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @article = @recording.recordable
  end

  def update
    # Create new immutable Article, update Recording to point to it
    @recording.recordable = Article.new(article_params)

    if @recording.save
      redirect_to @recording, notice: "Article was successfully updated."
    else
      @article = @recording.recordable
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recording.discard!
    redirect_to articles_path, notice: "Article was successfully deleted.", status: :see_other
  end

  private

  def set_recording
    @recording = recordings.find(params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :body)
  end

  def authorize_article_creation
    head :forbidden unless article_policy.can_create?
  end

  def authorize_article_editing
    head :forbidden unless article_policy.can_edit?(@recording)
  end

  def authorize_article_deletion
    head :forbidden unless article_policy.can_delete?(@recording)
  end

  def article_policy
    ArticlePolicy.new(person: Current.person, bucket: Current.bucket)
  end
end

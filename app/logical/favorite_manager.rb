class FavoriteManager
  def self.add!(user:, post:, force: false)
    begin
      Favorite.transaction(isolation: :serializable) do
        unless force
          if user.favorite_count >= user.favorite_limit
            raise Favorite::Error, "You can only keep up to #{user.favorite_limit} favorites. Upgrade your account to save more."
          end
        end

        Favorite.create!(:user_id => user.id, :post_id => post.id)
        post.append_user_to_fav_string(user.id)
        post.save
      end
    rescue ActiveRecord::RecordNotUnique
      raise Favorite::Error, "You have already favorited this post" unless force
    end
  end

  def self.remove!(user:, post:, post_id: nil)
    post_id = post ? post.id : post_id
    raise Favorite::Error, "Must specify a post or post_id to remove favorite" unless post_id
    Favorite.transaction(isolation: :serializable) do
      unless Favorite.for_user(user.id).where(:user_id => user.id, :post_id => post_id).exists?
        return
      end

      Favorite.for_user(user.id).where(post_id: post_id).destroy_all
      post.delete_user_from_fav_string(user.id) if post
      post.save if post
    end
  end

  def self.give_to_parent!(post)
    # TODO Much better and more intelligent logic can exist for this
    parent = post.parent
    return false unless parent
    post.favorites.each do |fav|
      FavoriteManager.remove!(user: fav.user, post: post)
      FavoriteManager.add!(user: fav.user, post: parent, force: true)
    end
    true
  end
end
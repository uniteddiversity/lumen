Lumen::App.controllers do
    
  get '/accounts/results', :provides => [:json, :html] do
    sign_in_required!
    scope = params[:scope]
    scope_id = params[:scope_id]
    @o = (params[:o] ? params[:o] : 'date').to_sym
    @account_id = params[:account_id]    
    @organisation_id = params[:organisation_id]
    @account_tag_id = params[:account_tag_id]     
    @accounts = case scope
    when 'network'
      current_account.network
    when 'group'
      group = Group.find(scope_id)
      membership_required!(group) unless group.open?
      group.members
    when 'conversation'
      conversation = Conversation.find(scope_id)
      membership_required!(conversation.group) unless conversation.group.open?
      conversation.participants
    when 'organisation'
      organisation = Organisation.find(scope_id)
      organisation.members
    when 'sector'
      sector = Sector.find(scope_id)
      sector.members
    end 
    @q = []
    @q << {:id => @account_id} if @account_id
    @q << {:id.in => Affiliation.where(organisation_id: @organisation_id).only(:account_id).map(&:account_id)} if @organisation_id
    @q << {:id.in => AccountTagship.where(account_tag_id: @account_tag_id).only(:account_id).map(&:account_id)} if @account_tag_id    
    @accounts = @accounts.and(@q)
    case content_type      
    when :json
      if params[:qtype]
        case params[:qtype].to_sym
        when :account
          {
            results: @accounts.where(:name => /#{params[:q]}/i).map { |account| {id: account.id.to_s, text: account.name} }
          }
        when :organisation
          {
            results: Organisation.where(:name => /#{params[:q]}/i).where(:id.in => Affiliation.where(:account_id.in => @accounts.only(:id).map(&:id)).only(:organisation_id).map(&:organisation_id)).map { |organisation| {id: organisation.id.to_s, text: organisation.name} }
          }
        when :account_tag
          {
            results: AccountTag.where(:name => /#{params[:q]}/i).where(:id.in => AccountTagship.where(:account_id.in => @accounts.only(:id).map(&:id)).only(:account_tag_id).map(&:account_tag_id)).map { |account_tag| {id: account_tag.id.to_s, text: account_tag.name} }
          }          
        end.to_json     
      end
    when :html
      @accounts = case @o
      when :name
        @accounts.order_by(:name.asc)
      when :date
        @accounts.order_by(:created_at.desc)
      when :updated
        @accounts.order_by([:has_picture.desc, :updated_at.desc])
      end      
      @accounts = @accounts.per_page(params[:per_page] || 10).page(params[:page])
      partial :'accounts/results'
    end
  end  
    
  get '/accounts/:id' do
    sign_in_required!
    @account = Account.find(params[:id]) || not_found
    @shared_conversations = current_account.conversation_posts.where(account_id: @account.id).order_by(:created_at.desc).limit(10).map(&:conversation).uniq if current_account
    erb :'accounts/account'
  end    
              
end
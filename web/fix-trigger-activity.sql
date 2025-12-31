-- Fix trigger_create_activity to handle UUID user_ids from comments
-- We need to cast NEW.user_id to TEXT because create_activity expects text

CREATE OR REPLACE FUNCTION public.trigger_create_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    activity_metadata JSONB;
BEGIN
    -- Crea attività basata su tabella e azione
    activity_metadata := '{}';
    
    IF TG_TABLE_NAME = 'articles' AND TG_OP = 'INSERT' THEN
        activity_metadata := jsonb_build_object(
            'article_title', NEW.title,
            'article_url', NEW.url,
            'domain', NEW.domain,
            'tags', NEW.tags
        );
        
        PERFORM create_activity(
            NEW.user_id,
            'article_created',
            'article',
            NEW.id,
            activity_metadata,
            LEFT(COALESCE(NEW.excerpt, NEW.content), 200),
            CASE WHEN NEW.is_public THEN 'public' ELSE 'followers' END
        );
    END IF;
    
    IF TG_TABLE_NAME = 'likes' AND TG_OP = 'INSERT' THEN
        -- Ottiene info articolo per metadata
        SELECT jsonb_build_object(
            'article_title', title,
            'article_url', url,
            'author', author
        ) INTO activity_metadata
        FROM articles WHERE id = NEW.article_id;
        
        PERFORM create_activity(
            NEW.user_id,
            'article_liked',
            'article',
            NEW.article_id,
            activity_metadata,
            NULL,
            'followers'
        );
    END IF;
    
    IF TG_TABLE_NAME = 'likes' AND TG_OP = 'DELETE' THEN
        -- Rimuove attività quando like viene rimosso
        DELETE FROM activity_feed 
        WHERE actor_id = OLD.user_id 
        AND action_type = 'article_liked'
        AND target_type = 'article'
        AND target_id = OLD.article_id
        AND created_at > NOW() - INTERVAL '24 hours'; -- Solo like recenti
        
        -- Aggiorna conteggio aggregato
        UPDATE activity_aggregates 
        SET count = count - 1,
            updated_at = NOW()
        WHERE actor_id = OLD.user_id
        AND action_type = 'article_liked'
        AND target_id = OLD.article_id
        AND count > 1;
        
        -- Elimina aggregato se conteggio diventa 0
        DELETE FROM activity_aggregates
        WHERE actor_id = OLD.user_id
        AND action_type = 'article_liked'  
        AND target_id = OLD.article_id
        AND count <= 1;
    END IF;
    
    IF TG_TABLE_NAME = 'comments' AND TG_OP = 'INSERT' THEN
        -- Ottiene info articolo per metadata
        SELECT jsonb_build_object(
            'article_title', a.title,
            'article_url', a.url,
            'comment_content', LEFT(NEW.content, 200)
        ) INTO activity_metadata
        FROM articles a WHERE a.id = NEW.article_id;
        
        PERFORM create_activity(
            NEW.user_id::text, -- <--- CAST ADDED HERE
            'comment_created',
            'article',
            NEW.article_id,
            activity_metadata || jsonb_build_object('comment_id', NEW.id),
            LEFT(NEW.content, 200),
            'public'
        );
    END IF;
    
    IF TG_TABLE_NAME = 'user_follows' AND TG_OP = 'INSERT' THEN
        -- Ottiene info utente seguito
        SELECT jsonb_build_object(
            'followed_user_name', COALESCE(name, email),
            'followed_user_bio', bio
        ) INTO activity_metadata
        FROM users WHERE id = NEW.following_id;
        
        PERFORM create_activity(
            NEW.follower_id,
            'user_followed',
            'user',
            NEW.following_id::UUID,
            activity_metadata,
            NULL,
            'public'
        );
    END IF;
    
    IF TG_TABLE_NAME = 'user_follows' AND TG_OP = 'DELETE' THEN
        -- Rimuove attività follow (opzionale - potresti voler mantenere la cronologia)
        DELETE FROM activity_feed 
        WHERE actor_id = OLD.follower_id 
        AND action_type = 'user_followed'
        AND target_type = 'user'
        AND target_id = OLD.following_id::UUID
        AND created_at > NOW() - INTERVAL '24 hours';
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$function$

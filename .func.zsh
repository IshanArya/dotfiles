delete_gone_branches() {
    # Fetch and prune branches that no longer exist on the remote
    git fetch --prune

    branches_to_delete=$(git branch -vv | grep ': gone' | awk '{print $1}')
    
    if [ -z "$branches_to_delete" ]; then
        echo "No local branches to delete."
        return
    fi

    echo "The following local branches have been deleted on the remote and will be removed locally:"
    echo "$branches_to_delete"
    echo

    read "confirmation?Are you sure you want to delete these branches? (y/n): "

    if [ "$confirmation" = "y" ]; then
        echo "$branches_to_delete" | xargs -r git branch -D
        echo "Deleted the local branches."
    else
        echo "Aborted. No branches were deleted."
    fi
}
package commands

import (
	"github.com/spf13/cobra"
)

func (ctx *CmdCtx) UsersSchemaPrintRunE() func(cmd *cobra.Command, args []string) (err error) {
	return func(cmd *cobra.Command, args []string) (err error) {
		return nil
	}
}

func (ctx *CmdCtx) UsersGetRunE() func(cmd *cobra.Command, args []string) (err error) {
	return func(cmd *cobra.Command, args []string) (err error) {
		// username := args[0].
		return nil
	}
}

func (ctx *CmdCtx) UsersListRunE() func(cmd *cobra.Command, args []string) (err error) {
	return func(cmd *cobra.Command, args []string) (err error) {
		return nil
	}
}

func (ctx *CmdCtx) UsersAddRunE() func(cmd *cobra.Command, args []string) (err error) {
	return func(cmd *cobra.Command, args []string) (err error) {
		return nil
	}
}

func (ctx *CmdCtx) UsersUpdateRunE() func(cmd *cobra.Command, args []string) (err error) {
	return func(cmd *cobra.Command, args []string) (err error) {
		return nil
	}
}

func (ctx *CmdCtx) UsersDeleteRunE() func(cmd *cobra.Command, args []string) (err error) {
	return func(cmd *cobra.Command, args []string) (err error) {
		// username := args[0].
		return nil
	}
}

func (ctx *CmdCtx) UsersGroupsListRunE() func(cmd *cobra.Command, args []string) (err error) {
	return func(cmd *cobra.Command, args []string) (err error) {
		return nil
	}
}

func (ctx *CmdCtx) UsersGroupsAddRunE() func(cmd *cobra.Command, args []string) (err error) {
	return func(cmd *cobra.Command, args []string) (err error) {
		// groupName := args[0].
		return nil
	}
}

func (ctx *CmdCtx) UsersGroupsDeleteRunE() func(cmd *cobra.Command, args []string) (err error) {
	return func(cmd *cobra.Command, args []string) (err error) {
		// groupName := args[0].
		return nil
	}
}

import os

# Airflow package
from airflow.hooks.base import BaseHook
from airflow.providers.slack.operators.slack import SlackAPIPostOperator


def send_slack_notification(slack_msg, env_var_channel="SLACK_DEFAULT_CHANNEL"):
    """
    context parameter from the execute method is not used
    """
    slack_channel = os.environ[env_var_channel]

    notification = SlackAPIPostOperator(
        task_id="slack_operator",
        token=BaseHook.get_connection("slack").password,
        text=slack_msg,
        channel=slack_channel,
        username="airflow",
    )

    return notification.execute(context=None)

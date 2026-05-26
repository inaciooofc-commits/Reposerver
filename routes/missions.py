# routes/missions.py

from flask import Blueprint, render_template, session, redirect, url_for, flash
from .decorators import login_required
from utils import load_users, save_users, load_missions
from config import AppConfig

missions_bp = Blueprint(
    'missions_bp',
    __name__,
    template_folder='../templates'
)

@missions_bp.route('/missions')
@login_required
def list_missions():
    """Displays the list of available missions to the user."""
    missions = load_missions()
    user_data = load_users().get(session['username'], {})

    # Here you could add logic to check which missions the user has already completed today.
    # For now, we will just display all of them.

    return render_template(
        'missions.html',
        title="Quadro de Missões",
        accent=AppConfig.get('theme_accent'),
        second=AppConfig.get('theme_second'),
        bg=AppConfig.get('theme_bg'),
        daily_missions=missions.get('daily_missions', []),
        special_missions=missions.get('special_missions', []),
        user_level=user_data.get('level', 1)
    )

@missions_bp.route('/missions/claim/<mission_id>', methods=['POST'])
@login_required
def claim_mission(mission_id):
    """Allows a user to claim a reward for a completed mission."""
    users = load_users()
    user_data = users.get(session['username'])
    missions = load_missions()

    all_missions = missions.get('daily_missions', []) + missions.get('special_missions', [])
    mission_to_claim = next((m for m in all_missions if m['id'] == mission_id), None)

    if not mission_to_claim:
        flash("Missão não encontrada!", "danger")
        return redirect(url_for('.list_missions'))

    # Here, you would add logic to verify if the user has actually completed the mission.
    # For this example, we'll assume they have and grant the reward.

    reward = mission_to_claim.get('reward', {})
    user_data['xp'] = user_data.get('xp', 0) + reward.get('xp', 0)
    user_data['gold'] = user_data.get('gold', 0) + reward.get('gold', 0)

    # Check for level up
    required_xp = 100 * (user_data.get('level', 1) ** 2)
    if user_data['xp'] >= required_xp:
        user_data['level'] += 1
        user_data['xp'] -= required_xp
        flash(f"Parabéns, você avançou para o Nível {user_data['level']}!", "success")

    save_users(users)
    flash(f"Recompensa da missão '{mission_to_claim['title']}' resgatada!", "success")

    return redirect(url_for('.list_missions'))

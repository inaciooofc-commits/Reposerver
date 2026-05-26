# routes/shop.py

from flask import Blueprint, render_template, session, redirect, url_for, flash
from .decorators import login_required
from utils import load_users, save_users, load_shop
from config import AppConfig

shop_bp = Blueprint(
    'shop_bp',
    __name__,
    template_folder='../templates'
)

@shop_bp.route('/shop')
@login_required
def list_items():
    """Displays the shop with items available for purchase."""
    shop_data = load_shop()
    user_data = load_users().get(session['username'], {})

    return render_template(
        'shop.html',
        title="Loja Ninja",
        accent=AppConfig.get('theme_accent'),
        second=AppConfig.get('theme_second'),
        bg=AppConfig.get('theme_bg'),
        items=shop_data.get('items', []),
        user_gold=user_data.get('gold', 0)
    )

@shop_bp.route('/shop/buy/<item_id>', methods=['POST'])
@login_required
def buy_item(item_id):
    """Handles the purchase of an item from the shop."""
    users = load_users()
    user_data = users.get(session['username'])
    shop_data = load_shop()

    item_to_buy = next((item for item in shop_data.get('items', []) if item['id'] == item_id), None)

    if not item_to_buy:
        flash("Item não encontrado na loja!", "danger")
        return redirect(url_for('.list_items'))

    user_gold = user_data.get('gold', 0)
    item_price = item_to_buy.get('price', 0)

    if user_gold < item_price:
        flash("Você não tem Ryo (gold) suficiente para comprar este item!", "warning")
        return redirect(url_for('.list_items'))

    # Deduct gold and apply item effect
    user_data['gold'] -= item_price

    if item_to_buy['type'] == 'currency':
        if item_to_buy['id'] == 'credits_10':
            user_data['credits'] = user_data.get('credits', 0) + 10
            flash(f"Você comprou {item_to_buy['name']} e recebeu 10 créditos!", "success")

    elif item_to_buy['type'] == 'cosmetic':
        if 'inventory' not in user_data:
            user_data['inventory'] = []
        user_data['inventory'].append(item_to_buy['id'])
        flash(f"Você comprou o item cosmético: {item_to_buy['name']}!", "success")

    else:
        # For now, other item types don't have a direct effect.
        flash(f"Você comprou {item_to_buy['name']}!", "success")

    save_users(users)
    return redirect(url_for('.list_items'))

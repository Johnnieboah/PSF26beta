#!/usr/bin/env python3
"""
Roster Optimization Analysis Script
Analyzes different strategies to make teams struggle less with roster cuts
"""

import csv

def main():
    print('🔧 ROSTER OPTIMIZATION ANALYSIS - REDUCING TEAM STRUGGLES')
    print('=' * 80)
    
    # 2025 NFL Salary Cap
    NFL_SALARY_CAP = 255_400_000  # $255.4M
    
    print(f'📊 2025 NFL Salary Cap: ${NFL_SALARY_CAP:,}')
    print('🎯 Goal: Make teams struggle less while maintaining realistic challenges')
    print('=' * 80)
    
    # Team name mapping
    team_mapping = {
        'Cleveland': 'CLE', 'San Francisco': 'SF', 'New York N': 'NYG',
        'Washington': 'WAS', 'Atlanta': 'ATL', 'Las Vegas': 'LV',
        'Jacksonville': 'JAX', 'Houston': 'HOU', 'Indianapolis': 'IND',
        'Dallas': 'DAL', 'Buffalo': 'BUF', 'Miami': 'MIA',
        'Chicago': 'CHI', 'Kansas City': 'KC', 'Green Bay': 'GB',
        'Tennessee': 'TEN', 'Baltimore': 'BAL', 'Carolina': 'CAR',
        'Los Angeles N': 'LAR', 'New England': 'NE', 'New Orleans': 'NO',
        'Philadelphia': 'PHI', 'Cincinnati': 'CIN', 'Minnesota': 'MIN',
        'Denver': 'DEN', 'Arizona': 'ARI', 'Detroit': 'DET',
        'Tampa Bay': 'TB', 'Seattle': 'SEA', 'Pittsburgh': 'PIT',
        'New York A': 'NYJ', 'Los Angeles A': 'LAC'
    }
    
    # Analyze each team's roster and contract situation
    team_analysis = {}
    
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            team = row.get('Team', '').strip()
            contract_apy_str = row.get('contractAPY_M', '').strip()
            overall = row.get('overallRating', '').strip()
            position = row.get('Position', '').strip()
            
            if team and contract_apy_str and overall:
                try:
                    contract_apy = float(contract_apy_str)
                    overall_int = int(overall)
                    
                    if team not in team_analysis:
                        team_analysis[team] = {
                            'total_contracts': 0,
                            'player_count': 0,
                            'players': []
                        }
                    
                    team_analysis[team]['total_contracts'] += contract_apy * 1_000_000
                    team_analysis[team]['player_count'] += 1
                    team_analysis[team]['players'].append({
                        'overall': overall_int,
                        'position': position,
                        'apy': contract_apy,
                        'apy_dollars': int(contract_apy * 1_000_000)
                    })
                    
                except ValueError:
                    continue
    
    print('📊 CURRENT SITUATION ANALYSIS:')
    print('=' * 80)
    
    # Analyze current situation
    teams_hard_to_cut = []
    teams_easy_to_cut = []
    
    for team_name in sorted(team_analysis.keys()):
        if team_name in team_mapping:
            total_contracts = team_analysis[team_name]['total_contracts']
            player_count = team_analysis[team_name]['player_count']
            over_cap = total_contracts - NFL_SALARY_CAP
            
            # Sort players by APY (highest to lowest) for cut analysis
            players_sorted = sorted(team_analysis[team_name]['players'], key=lambda x: x['apy'], reverse=True)
            
            if player_count >= 20:
                top_20_cut_savings = sum(player['apy_dollars'] for player in players_sorted[:20])
                remaining_contracts = total_contracts - top_20_cut_savings
                
                # Analyze the impact of cutting top 20
                remaining_players = players_sorted[20:]
                if remaining_players:
                    avg_overall_remaining = sum(p['overall'] for p in remaining_players) / len(remaining_players)
                    top_players_lost = sum(1 for p in players_sorted[:20] if p['overall'] >= 85)
                else:
                    avg_overall_remaining = 0
                    top_players_lost = 0
                
                # Categorize difficulty
                if top_players_lost >= 5:
                    teams_hard_to_cut.append(team_name)
                else:
                    teams_easy_to_cut.append(team_name)
                
                print(f'{team_name:<20} | Over Cap: ${over_cap:>8,.0f} | Good Players Lost: {top_players_lost:>2} | Remaining Avg: {avg_overall_remaining:>5.1f}')
    
    print('=' * 80)
    print(f'Teams that will struggle: {len(teams_hard_to_cut)}')
    print(f'Teams that can easily cut: {len(teams_easy_to_cut)}')
    
    # Analyze optimization strategies
    print(f'\n🔧 OPTIMIZATION STRATEGIES ANALYSIS:')
    print('=' * 80)
    
    print('1. 📉 REDUCE CONTRACT VALUES (Maintain Real NFL Contracts)')
    print('   - Scale down all contracts by a small percentage')
    print('   - Preserves real NFL contract authenticity')
    print('   - Reduces over-cap amounts across all teams')
    print()
    
    print('2. 🎯 TARGETED CONTRACT REDUCTION (Smart Scaling)')
    print('   - Reduce contracts for teams struggling the most')
    print('   - Keep contracts for teams already in good shape')
    print('   - More nuanced approach')
    print()
    
    print('3. 🏈 INCREASE SALARY CAP (Gameplay Adjustment)')
    print('   - Raise cap from $255.4M to $260M or $265M')
    print('   - Makes roster management easier')
    print('   - Less realistic but better gameplay')
    print()
    
    print('4. 🔄 CONTRACT RESTRUCTURING (Advanced Strategy)')
    print('   - Convert high APY contracts to longer terms')
    print('   - Reduce immediate cap hit')
    print('   - More complex but realistic')
    print()
    
    # Show specific recommendations for struggling teams
    print(f'\n🎯 SPECIFIC RECOMMENDATIONS FOR STRUGGLING TEAMS:')
    print('=' * 80)
    
    for team_name in teams_hard_to_cut:
        analysis = team_analysis[team_name]
        total_contracts = analysis['total_contracts']
        over_cap = total_contracts - NFL_SALARY_CAP
        
        # Calculate needed reduction to make cuts easier
        players_sorted = sorted(analysis['players'], key=lambda x: x['apy'], reverse=True)
        top_20_cut_savings = sum(player['apy_dollars'] for player in players_sorted[:20])
        remaining_contracts = total_contracts - top_20_cut_savings
        
        # Calculate what reduction would make this team "easy to cut"
        # Easy = lose fewer than 5 good players
        remaining_players = players_sorted[20:]
        if remaining_players:
            good_players_in_top_20 = sum(1 for p in players_sorted[:20] if p['overall'] >= 85)
            
            if good_players_in_top_20 >= 5:
                # Calculate how much we need to reduce contracts to make cuts easier
                # We want to reduce the over-cap amount so that cutting 20 players is more manageable
                target_over_cap = over_cap * 0.6  # Reduce over-cap by 40%
                needed_reduction = over_cap - target_over_cap
                reduction_percentage = (needed_reduction / total_contracts) * 100
                
                print(f'{team_name}:')
                print(f'  Current over cap: ${over_cap:,}')
                print(f'  Good players lost with cuts: {good_players_in_top_20}')
                print(f'  Recommended: Reduce contracts by {reduction_percentage:.1f}%')
                print(f'  This would reduce over-cap to ${target_over_cap:,.0f}')
                print()
    
    # Overall recommendation
    print(f'\n💡 OVERALL RECOMMENDATION:')
    print('=' * 60)
    print('Based on the analysis, I recommend a combination approach:')
    print()
    print('1. 🎯 Apply a 5-10% contract reduction to ALL teams')
    print('   - This preserves real NFL contract authenticity')
    print('   - Reduces over-cap amounts across the board')
    print('   - Makes roster cuts more manageable')
    print()
    print('2. 📊 Benefits of this approach:')
    print('   - Teams still need to make cuts (maintains challenge)')
    print('   - Fewer teams lose 5+ good players')
    print('   - More balanced roster management experience')
    print('   - Realistic NFL contract values maintained')
    print()
    print('3. 🎮 Gameplay impact:')
    print('   - Users still face strategic decisions')
    print('   - Roster management remains engaging')
    print('   - Less punitive for struggling teams')
    print('   - Better balance between challenge and fun')

if __name__ == "__main__":
    main()



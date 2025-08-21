#!/usr/bin/env python3
"""
Roster Cut Analysis Script
Analyzes which teams would have the hardest time cutting 20 players to get under cap
"""

import csv

def main():
    print('✂️  ROSTER CUT ANALYSIS - CAP COMPLIANCE WITH 20 PLAYER CUTS')
    print('=' * 80)
    
    # 2025 NFL Salary Cap
    NFL_SALARY_CAP = 255_400_000  # $255.4M
    
    print(f'📊 2025 NFL Salary Cap: ${NFL_SALARY_CAP:,}')
    print(f'🎯 Target: Cut 20 players to get under cap')
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
    
    # Calculate over cap amounts and analyze cut scenarios
    print('Team Name           | Team Abbr | Total Contracts | Over Cap | Players | Cut 20 Analysis')
    print('=' * 100)
    
    teams_hard_to_cut = []
    teams_easy_to_cut = []
    teams_impossible_to_cut = []
    
    for team_name in sorted(team_analysis.keys()):
        if team_name in team_mapping:
            team_abbr = team_mapping[team_name]
            total_contracts = team_analysis[team_name]['total_contracts']
            player_count = team_analysis[team_name]['player_count']
            over_cap = total_contracts - NFL_SALARY_CAP
            
            # Sort players by APY (highest to lowest) for cut analysis
            players_sorted = sorted(team_analysis[team_name]['players'], key=lambda x: x['apy'], reverse=True)
            
            # Calculate what cutting the 20 highest-paid players would save
            if player_count >= 20:
                top_20_cut_savings = sum(player['apy_dollars'] for player in players_sorted[:20])
                remaining_contracts = total_contracts - top_20_cut_savings
                cap_compliance_after_cuts = remaining_contracts <= NFL_SALARY_CAP
                
                # Analyze the impact of cutting top 20
                remaining_players = players_sorted[20:]
                if remaining_players:
                    avg_overall_remaining = sum(p['overall'] for p in remaining_players) / len(remaining_players)
                    top_players_lost = sum(1 for p in players_sorted[:20] if p['overall'] >= 85)
                else:
                    avg_overall_remaining = 0
                    top_players_lost = 0
                
                # Categorize difficulty
                if not cap_compliance_after_cuts:
                    difficulty = "🔴 IMPOSSIBLE"
                    teams_impossible_to_cut.append(team_name)
                elif top_players_lost >= 10:  # Lost 10+ good players
                    difficulty = "🟡 HARD"
                    teams_hard_to_cut.append(team_name)
                elif top_players_lost >= 5:  # Lost 5+ good players
                    difficulty = "🟠 MODERATE"
                    teams_hard_to_cut.append(team_name)
                else:
                    difficulty = "🟢 EASY"
                    teams_easy_to_cut.append(team_name)
                
                print(f'{team_name:<20} | {team_abbr:>9} | ${total_contracts:>14,.0f} | ${over_cap:>8,.0f} | {player_count:>7} | {difficulty}')
                
                # Store analysis results
                team_analysis[team_name]['cut_analysis'] = {
                    'over_cap_amount': over_cap,
                    'top_20_cut_savings': top_20_cut_savings,
                    'remaining_contracts': remaining_contracts,
                    'cap_compliant_after_cuts': cap_compliance_after_cuts,
                    'avg_overall_remaining': avg_overall_remaining,
                    'top_players_lost': top_players_lost,
                    'difficulty': difficulty
                }
    
    print('=' * 100)
    
    # Summary analysis
    print(f'\n📊 CUT DIFFICULTY ANALYSIS:')
    print('=' * 60)
    print(f'Teams that can easily cut 20 players: {len(teams_easy_to_cut)}')
    print(f'Teams that will struggle with cuts: {len(teams_hard_to_cut)}')
    print(f'Teams that cannot get under cap with 20 cuts: {len(teams_impossible_to_cut)}')
    
    # Show teams that will struggle
    if teams_hard_to_cut:
        print(f'\n🟡 TEAMS THAT WILL STRUGGLE WITH 20 PLAYER CUTS:')
        print('=' * 60)
        
        for team_name in teams_hard_to_cut:
            analysis = team_analysis[team_name]['cut_analysis']
            print(f'{team_name}:')
            print(f'  Over cap by: ${analysis["over_cap_amount"]:,}')
            print(f'  Savings from cutting top 20: ${analysis["top_20_cut_savings"]:,}')
            print(f'  Remaining contracts after cuts: ${analysis["remaining_contracts"]:,}')
            print(f'  Cap compliant after cuts: {"✅ YES" if analysis["cap_compliant_after_cuts"] else "❌ NO"}')
            print(f'  Good players lost (85+ overall): {analysis["top_players_lost"]}')
            print(f'  Average overall of remaining players: {analysis["avg_overall_remaining"]:.1f}')
            print()
    
    # Show teams that cannot get under cap
    if teams_impossible_to_cut:
        print(f'\n🔴 TEAMS THAT CANNOT GET UNDER CAP WITH 20 CUTS:')
        print('=' * 60)
        
        for team_name in teams_impossible_to_cut:
            analysis = team_analysis[team_name]['cut_analysis']
            print(f'{team_name}:')
            print(f'  Over cap by: ${analysis["over_cap_amount"]:,}')
            print(f'  Savings from cutting top 20: ${analysis["top_20_cut_savings"]:,}')
            print(f'  Still over cap by: ${analysis["remaining_contracts"] - NFL_SALARY_CAP:,}')
            print(f'  Need to cut additional players or restructure contracts!')
            print()
    
    # Show teams that can easily make cuts
    if teams_easy_to_cut:
        print(f'\n🟢 TEAMS THAT CAN EASILY MAKE 20 PLAYER CUTS:')
        print('=' * 60)
        
        for team_name in teams_easy_to_cut[:10]:  # Show first 10
            analysis = team_analysis[team_name]['cut_analysis']
            print(f'{team_name}:')
            print(f'  Over cap by: ${analysis["over_cap_amount"]:,}')
            print(f'  Savings from cutting top 20: ${analysis["top_20_cut_savings"]:,}')
            print(f'  Good players lost (85+ overall): {analysis["top_players_lost"]}')
            print(f'  Average overall of remaining players: {analysis["avg_overall_remaining"]:.1f}')
            print()

if __name__ == "__main__":
    main()
